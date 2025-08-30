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
    Q_PROPERTY(QString currentPhase READ currentPhase NOTIFY scanPhaseChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(quint64 totalBytesFound READ totalBytesFound NOTIFY totalBytesFoundChanged)

public:
    explicit Scanner(QObject* parent = nullptr);
    ~Scanner();

    double progress() const { return m_progress; }
    quint64 totalBytesFound() const { return m_totalBytesFound; }

    // Load path to a rule YAML file (very simple parser)
    bool loadRulesFile(const QString& yamlPath);

    bool scanning() const { return m_scanning; }

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
    void progressChanged();
    void totalBytesFoundChanged();

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

    double m_progress = 0.0;
    quint64 m_totalBytesFound = 0;

    // runtime state
    bool m_scanning = false;
    QString m_currentPhase;
    int m_filesScanned = 0;
    QString m_currentPath;
};