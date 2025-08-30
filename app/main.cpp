#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QDebug>
#include "JunkModel.h"
#include "../core/Scanner.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    JunkModel model;
    Scanner scanner;

    QObject::connect(&scanner, &Scanner::found, [&](const Finding &f) {
        JunkItem it;
        it.path = f.path;
        it.bytes = f.bytes;
        it.ruleId = f.ruleId;
        it.explain = f.explain;
        model.addItem(it);
    });

    QObject::connect(&scanner, &Scanner::scanFinished, [&]() {
        qDebug("Scan finished");
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("junkModel", &model);
    engine.rootContext()->setContextProperty("scanner", &scanner);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qWarning() << "Failed to load qrc:/Main.qml, trying filesystem fallbacks...";
        QString exeDir = QCoreApplication::applicationDirPath();
        QStringList qmlCandidates;
        qmlCandidates << QDir::current().filePath("app/Main.qml")
                      << QDir(exeDir).filePath("../../app/Main.qml")
                      << QDir(exeDir).filePath("app/Main.qml");
        bool qmlLoaded = false;
        for (const QString &c : qmlCandidates) {
            qDebug() << "Trying QML file:" << c << "exists=" << QFile::exists(c);
            if (QFile::exists(c)) {
                engine.load(QUrl::fromLocalFile(c));
                if (!engine.rootObjects().isEmpty()) { qmlLoaded = true; break; }
            }
        }
        if (!qmlLoaded) {
            qCritical() << "Unable to load Main.qml. Tried:" << qmlCandidates;
            return -1;
        }
    }

    // Robust rules file lookup (try several likely locations)
    QString exeDir = QCoreApplication::applicationDirPath();
    QStringList candidates;
    candidates << QDir::current().filePath("rules/safe_caches.yaml")
               << QDir(exeDir).filePath("../../rules/safe_caches.yaml")
               << QDir(exeDir).filePath("../rules/safe_caches.yaml")
               << QDir::current().filePath("../rules/safe_caches.yaml");
    QString found;
    for (const QString &c : candidates) {
        qDebug() << "Checking rules file:" << c << "exists=" << QFile::exists(c);
        if (QFile::exists(c)) { found = c; break; }
    }
    if (found.isEmpty()) {
        qWarning() << "No rules YAML found. Tried:" << candidates;
    } else {
        if (!scanner.loadRulesFile(found)) {
            qWarning() << "Scanner failed to parse rules file at" << found;
        } else {
            qDebug() << "Loaded rules from" << found;
        }
    }

    return app.exec();
}