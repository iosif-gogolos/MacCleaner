#pragma once
#include <QAbstractListModel>
#include <QObject>
#include <vector>

struct JunkItem {
    QString path;
    quint64 bytes = 0;
    QString ruleId;
    QString explain;
};

class JunkModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles {
        PathRole = Qt::UserRole + 1,
        BytesRole,
        RuleRole,
        ExplainRole
    };

    explicit JunkModel(QObject* parent = nullptr);
    int rowCount(const QModelIndex &parent = QModelIndex{}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void clear();
    void addItem(const JunkItem& it);

    int count() const { return rowCount(); }

signals:
    void countChanged();

private:
    std::vector<JunkItem> m_items;
};
