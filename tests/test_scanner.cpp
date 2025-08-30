#include "../core/Scanner.h"
#include <QCoreApplication>
#include <QDebug>

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    Scanner s;
    QObject::connect(&s, &Scanner::found, [](const Finding& f){
        qDebug() << "FIND:" << f.path << f.bytes << f.ruleId << f.explain;
    });
    QString rules = QCoreApplication::applicationDirPath() + "/../rules/safe_caches.yaml";
    if (!s.loadRulesFile(rules)) {
        qWarning("Couldn't load rules at %s", qPrintable(rules));
        return 1;
    }
    s.startScan();
    return 0;
}
