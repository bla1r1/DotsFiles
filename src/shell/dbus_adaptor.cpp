#include "dbus_adaptor.hpp"
#include <iostream>

namespace b1air {

ShellDBusAdaptor::ShellDBusAdaptor(B1AirBridge* bridge, QObject* parent)
    : QDBusAbstractAdaptor(parent), m_bridge(bridge)
{
}

void ShellDBusAdaptor::Toggle(const QString& panel) {
    if (m_bridge) {
        std::cout << "[b1air-shell DBus] Toggle: " << panel.toStdString() << "\n";
        emit m_bridge->ipcTriggered("toggle", panel, "");
    }
}

void ShellDBusAdaptor::Open(const QString& panel, const QString& arg) {
    if (m_bridge) {
        std::cout << "[b1air-shell DBus] Open: " << panel.toStdString() << " arg: " << arg.toStdString() << "\n";
        emit m_bridge->ipcTriggered("open", panel, arg);
    }
}

void ShellDBusAdaptor::Close(const QString& panel) {
    if (m_bridge) {
        std::cout << "[b1air-shell DBus] Close: " << panel.toStdString() << "\n";
        emit m_bridge->ipcTriggered("close", panel, "");
    }
}

void ShellDBusAdaptor::ForceReload() {
    if (m_bridge) {
        std::cout << "[b1air-shell DBus] ForceReload\n";
        emit m_bridge->ipcTriggered("forceReload", "", "");
    }
}

QStringList ShellDBusAdaptor::GetActivePanels() {
    return {};
}

} // namespace b1air
