#pragma once

#include <QDBusAbstractAdaptor>
#include <QString>
#include <QStringList>
#include "b1air_bridge.hpp"

namespace b1air {

class ShellDBusAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.b1air.Shell")

public:
    explicit ShellDBusAdaptor(B1AirBridge* bridge, QObject* parent = nullptr);

public slots:
    void Toggle(const QString& panel);
    void Open(const QString& panel, const QString& arg = QString());
    void Close(const QString& panel = QString());
    void ForceReload();
    QStringList GetActivePanels();

signals:
    void PanelStateChanged(const QString& panel, bool visible);

private:
    B1AirBridge* m_bridge;
};

} // namespace b1air
