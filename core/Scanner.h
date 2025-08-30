#pragma once
#include <QObject>
#include <QString>
#include <QDateTime>
#include <vector>
#include <filesystem>

struct Finding {
    QString path;
    uint64_t bytes = 0;
    QString ruleId;
    QString explain;
};

class Scanner : public QObject {
    Q_OBJECT

    // Expose properties to QML (must not be placed inside 'signals:')
    Q_PROPERTY(bool scanning READ isScanning NOTIFY scanningChanged)
    Q_PROPERTY(QString currentPhase READ currentPhase NOTIFY scanPhaseChanged)

public:
    explicit Scanner(QObject* parent = nullptr);
    ~Scanner();

    // Load path to a rule YAML file (very simple parser)
    bool loadRulesFile(const QString& yamlPath);

    // Start scan from the loaded rules. Will emit found(...) for each finding.
    Q_INVOKABLE void startScan();

    // Accessors required by Q_PROPERTY
    bool isScanning() const;
    QString currentPhase() const;

signals:
    void found(const Finding& finding);
    void scanFinished();
    void progressUpdated(int scannedFiles, const QString& currentPath);
    void scanPhaseChanged(const QString& phase);
    void scanningChanged();

private:
    struct Rule {
        QString id;
        QString path; // can contain $HOME
        int min_age_days = 0;
        QString explain;
    };

    std::vector<Rule> m_rules;
    std::filesystem::path expandHome(const QString& p);
    bool parseSimpleYaml(const QString& text);
    void scanRule(const Rule& r);

    // runtime state
    bool m_scanning = false;
    QString m_currentPhase;
    int m_filesScanned = 0;
    QString m_currentPath;
};