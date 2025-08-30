#include "JunkModel.h"

JunkModel::JunkModel(QObject* parent) : QAbstractListModel(parent) {}

int JunkModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_items.size());
}

QVariant JunkModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid()) return {};
    int r = index.row();
    if (r < 0 || r >= (int)m_items.size()) return {};
    const auto &it = m_items[r];
    switch(role) {
        case PathRole: return it.path;
        case BytesRole: return QVariant::fromValue((qulonglong)it.bytes);
        case RuleRole: return it.ruleId;
        case ExplainRole: return it.explain;
        case Qt::DisplayRole: return it.path;
    }
    return {};
}

QHash<int, QByteArray> JunkModel::roleNames() const {
    QHash<int, QByteArray> rn;
    rn[PathRole] = "path";
    rn[BytesRole] = "bytes";
    rn[RuleRole] = "ruleId";
    rn[ExplainRole] = "explain";
    return rn;
}

void JunkModel::clear() {
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
}

void JunkModel::addItem(const JunkItem& it) {
    beginInsertRows(QModelIndex(), (int)m_items.size(), (int)m_items.size());
    m_items.push_back(it);
    endInsertRows();
    emit countChanged();
}