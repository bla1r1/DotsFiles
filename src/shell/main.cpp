// =============================================================================
// b1air-shell — Standalone Native C++20 / Qt6 Wayland Layer-Shell Desktop Shell
// Native D-Bus Control (org.b1air.Shell) • Direct C++ Bridge • Zero-Fork UI
// =============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QProcess>
#include <QDir>
#include <QStandardPaths>
#include <LayerShellQt/shell.h>
#include <iostream>
#include <csignal>
#include "b1air_bridge.hpp"
#include "dbus_adaptor.hpp"

int main(int argc, char* argv[]) {
    // ── CLI Dispatcher: Send command over D-Bus to running instance ──────────
    if (argc > 1) {
        QGuiApplication app(argc, argv);
        QString action = argv[1];
        QString target = (argc >= 3) ? argv[2] : "";
        QString arg = (argc >= 4) ? argv[3] : "";

        QDBusConnection bus = QDBusConnection::sessionBus();
        if (bus.isConnected()) {
            QDBusInterface iface("org.b1air.Shell", "/org/b1air/Shell", "org.b1air.Shell", bus);
            if (iface.isValid()) {
                if (action == "toggle") {
                    iface.call("Toggle", target);
                    return 0;
                } else if (action == "open") {
                    iface.call("Open", target, arg);
                    return 0;
                } else if (action == "close") {
                    iface.call("Close", target);
                    return 0;
                } else if (action == "forceReload" || action == "reload") {
                    iface.call("ForceReload");
                    return 0;
                }
            }
        }

        // Quickshell fallback if a legacy Quickshell process is running.
        QStringList qsArgs = {"-p", QDir::homePath() + "/.config/quickshell/Main.qml", "ipc", "call", "main"};
        if (action == "close") {
            qsArgs << "close";
        } else if (!target.isEmpty()) {
            qsArgs << action << target << arg;
        } else {
            qsArgs << action << "" << "";
        }
        return QProcess::execute("qs", qsArgs) == 0 ? 0 : 1;
    }

    // ── Setup Environment & Performance Flags ────────────────────────────────
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QML_DISABLE_DISK_CACHE", "0");

    // Enable Wayland Layer Shell protocol support in Qt6
    LayerShellQt::Shell::useLayerShell();

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-shell");
    app.setApplicationDisplayName("b1air Desktop Environment");
    app.setOrganizationName("bla1r1");

    B1AirBridge bridge;

    // ── Register D-Bus Service (org.b1air.Shell) ─────────────────────────────
    ShellDBusAdaptor adaptor(&bridge, &app);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.registerService("org.b1air.Shell")) {
        bus.registerObject("/org/b1air/Shell", &app);
        std::cout << "[b1air-shell] Registered D-Bus service 'org.b1air.Shell' at '/org/b1air/Shell'\n";
    } else {
        std::cerr << "[b1air-shell] Warning: Could not register D-Bus service 'org.b1air.Shell'\n";
    }

    // ── Setup QQmlApplicationEngine ──────────────────────────────────────────
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("b1air", &bridge);
    engine.rootContext()->setContextProperty("Bridge", &bridge);

    QString homePath = QDir::homePath();
    engine.addImportPath("/usr/lib/qt6/qml");
    engine.addImportPath(homePath + "/DotsFiles/src/shell/qml");
    engine.addImportPath(homePath + "/.config/quickshell");
    engine.addImportPath(homePath + "/.config/b1air-shell");

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-shell QML] " << w.toString().toStdString() << "\n";
        }
    });
    QStringList searchPaths = {
        homePath + "/.config/b1air-shell/Main.qml",
        "/usr/share/b1air-shell/qml/Main.qml",
        homePath + "/DotsFiles/src/shell/qml/Main.qml",
        homePath + "/.config/quickshell/Main.qml",
        homePath + "/DotsFiles/.config/quickshell/Main.qml"
    };

    QString mainQml;
    for (const QString& path : searchPaths) {
        if (QFile::exists(path)) {
            mainQml = path;
            break;
        }
    }

    if (mainQml.isEmpty()) {
        std::cerr << "[b1air-shell] Error: Main.qml not found in any search path!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(mainQml));

    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-shell] Error: Failed to load QML root component: " << mainQml.toStdString() << "\n";
        return -1;
    }

    std::cout << "[b1air-shell] Native Qt6 Desktop Shell initialized successfully over D-Bus.\n";
    return app.exec();
}
