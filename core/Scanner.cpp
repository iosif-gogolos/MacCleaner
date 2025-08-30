#include "Scanner.h"
#include <fstream>
#include <sstream>
#include <chrono>
#include <sys/stat.h>

Scanner::Scanner(QObject* parent) : QObject(parent) {}
Scanner::~Scanner() = default;

static QString trim(const QString& s) {
    return s.trimmed();
}

std::filesystem::path Scanner::expandHome(const QString& p) {
    QString s = p;
    if (s.startsWith("$HOME")) {
        QByteArray home = qgetenv("HOME");
        s.replace("$HOME", QString(home));
    } else if (s.startsWith("~")) {
        QByteArray home = qgetenv("HOME");
        s.replace(0,1, QString(home));
    }
    return std::filesystem::path(s.toStdString());
}

bool Scanner::loadRulesFile(const QString& yamlPath) {
    std::ifstream ifs(yamlPath.toStdString());
    if (!ifs) return false;
    std::ostringstream ss;
    ss << ifs.rdbuf();
    return parseSimpleYaml(QString::fromStdString(ss.str()));
}

bool Scanner::parseSimpleYaml(const QString& text) {
    // Very small line-based parser for our simple YAML structure
    m_rules.clear();
    QStringList lines = text.split('\n');
    Rule cur;
    bool inItem = false;
    for (const QString& raw : lines) {
        QString line = raw.trimmed();
        if (line.startsWith("- ")) {
            // begin new item
            if (inItem) m_rules.push_back(cur);
            cur = Rule();
            inItem = true;
            // maybe inline fields after "- "
            QString rest = line.mid(2).trimmed();
            if (rest.startsWith("id:")) {
                cur.id = trim(rest.mid(3));
            }
            continue;
        }
        if (!inItem) continue;
        if (line.startsWith("id:")) {
            cur.id = trim(line.mid(3));
        } else if (line.startsWith("path:")) {
            QString p = trim(line.mid(5));
            // remove optional quotes
            if ((p.startsWith('"') && p.endsWith('"')) || (p.startsWith('\'') && p.endsWith('\''))) {
                p = p.mid(1, p.length()-2);
            }
            cur.path = p;
        } else if (line.startsWith("min_age_days:")) {
            bool ok = false;
            int v = trim(line.mid(QString("min_age_days:").length())).toInt(&ok);
            if (ok) cur.min_age_days = v;
        } else if (line.startsWith("explain:")) {
            QString e = trim(line.mid(QString("explain:").length()));
            if ((e.startsWith('"') && e.endsWith('"')) || (e.startsWith('\'') && e.endsWith('\''))) {
                e = e.mid(1, e.length()-2);
            }
            cur.explain = e;
        }
    }
    if (inItem) m_rules.push_back(cur);
    return !m_rules.empty();
}

void Scanner::startScan() {
    // prepare state
    m_scanning = true;
    m_filesScanned = 0;
    m_currentPath.clear();
    m_currentPhase = "Starting scan";
    emit scanningChanged();
    emit scanPhaseChanged(m_currentPhase);

    for (const auto& r : m_rules) {
        scanRule(r);
    }

    m_scanning = false;
    m_currentPhase = "Scan complete";
    emit scanPhaseChanged(m_currentPhase);
    emit scanningChanged();
    emit scanFinished();
}

#include <filesystem>
#include <sys/types.h>
#include <unistd.h>

bool Scanner::isScanning() const {
    return m_scanning;
}

QString Scanner::currentPhase() const {
    return m_currentPhase;
}

void Scanner::scanRule(const Rule& r) {
    namespace fs = std::filesystem;
    fs::path root = expandHome(r.path);

    m_currentPhase = "Scanning " + r.explain;
    emit scanPhaseChanged(m_currentPhase);

    std::error_code ec;
    if (!fs::exists(root, ec)) return;

    // Compute cutoff time
    using namespace std::chrono;
    auto now = system_clock::now();
    auto cutoff = now - hours(24 * std::max(0, r.min_age_days));

    for (auto it = fs::recursive_directory_iterator(root, fs::directory_options::skip_permission_denied, ec); it != fs::recursive_directory_iterator(); it.increment(ec)) {
        const fs::path p = it->path();
        std::error_code st_ec;
        auto ftime = fs::last_write_time(p, st_ec);
        if (st_ec) continue;
        auto sctp = time_point_cast<system_clock::duration>(ftime - fs::file_time_type::clock::now() + system_clock::now());
        if (r.min_age_days > 0 && sctp > cutoff) {
            // too new, skip
            continue;
        }
        uint64_t sz = 0;
        if (fs::is_regular_file(p, st_ec)) {
            sz = (uint64_t)fs::file_size(p, st_ec);
        } else {
            // approximate directory size as zero for quick scan
            sz = 0;
        }
        Finding f;
        f.path = QString::fromStdString(p.string());
        f.bytes = sz;
        f.ruleId = r.id;
        f.explain = r.explain;

        // update progress counters and emit progress
        ++m_filesScanned;
        m_currentPath = f.path;
        emit progressUpdated(m_filesScanned, m_currentPath);

        emit found(f);
    }
}