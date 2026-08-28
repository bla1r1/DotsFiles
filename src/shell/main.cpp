#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QLocalServer>
#include <QLocalSocket>
#include <QDir>
#include <QStandardPaths>
#include <LayerShellQt/shell.h>
#include <iostream>
#include <csignal>
#include "b1air_bridge.hpp"

// =============================================================================
// b1air-shell — Standalone Native C++20 / Qt6 Wayland Layer-Shell Desktop Shell
// Sub-millisecond IPC, zero-fork UI, direct memory synchronization.
// =============================================================================

static const char* SOCKET_PATH = "/tmp/b1air-shell.sock";

int main(int argc, char* argv[]) {
    // ── CLI Dispatcher: Send command to running instance if one exists ───────
    if (argc > 1) {
        QString fullCmd;
        for (int i = 1; i < argc; ++i) {
            if (i > 1) fullCmd += " ";
            fullCmd += argv[i];
        }

        QLocalSocket socket;
        socket.connectToServer(SOCKET_PATH);
        if (socket.waitForConnected(150)) {
            socket.write(fullCmd.toUtf8());
            socket.flush();
            socket.waitForBytesWritten(150);
            return 0; // Successfully dispatched to running daemon in <1ms!
        }

        // Quickshell IPC Fallback:
        // Ensure WAYLAND_DISPLAY is discovered if unset
        if (qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")) {
            QString rundir = qEnvironmentVariable("XDG_RUNTIME_DIR");
            if (!rundir.isEmpty()) {
                for (int i = 0; i < 5; ++i) {
                    QString sock = QString("%1/wayland-%2").arg(rundir).arg(i);
                    if (QFile::exists(sock)) {
                        qputenv("WAYLAND_DISPLAY", QString("wayland-%1").arg(i).toUtf8());
                        break;
                    }
                }
            }
        }

        QString action = argv[1];
        QString target = (argc >= 3) ? argv[2] : "";
        QString arg = (argc >= 4) ? argv[3] : "";

        QString qsCmd;
        if (action == "close") {
            qsCmd = "qs -p ~/.config/quickshell/Main.qml ipc call main close >/dev/null 2>&1";
        } else if (!target.isEmpty()) {
            qsCmd = QString("qs -p ~/.config/quickshell/Main.qml ipc call main %1 %2 '%3' >/dev/null 2>&1")
                        .arg(action, target, arg);
        } else {
            qsCmd = QString("qs -p ~/.config/quickshell/Main.qml ipc call main %1 '' '' >/dev/null 2>&1")
                        .arg(action);
        }
        return (std::system(qsCmd.toUtf8().constData()) == 0) ? 0 : 1;
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

    // ── Setup UNIX Socket IPC Server for Sub-millisecond Commands ────────────
    QLocalServer::removeServer(SOCKET_PATH);
    QLocalServer server;
    if (!server.listen(SOCKET_PATH)) {
        std::cerr << "[b1air-shell] Warning: Could not listen on " << SOCKET_PATH << "\n";
    }

    B1AirBridge bridge;

    QObject::connect(&server, &QLocalServer::newConnection, [&server, &bridge]() {
        QLocalSocket* sock = server.nextPendingConnection();
        if (!sock) return;
        QObject::connect(sock, &QLocalSocket::readyRead, [sock, &bridge]() {
            QString cmd = QString::fromUtf8(sock->readAll()).trimmed();
            if (!cmd.isEmpty()) {
                QStringList parts = cmd.split(" ", Qt::SkipEmptyParts);
                QString action = parts.value(0, "open");
                QString target = parts.value(1, "launcher");
                QString arg = parts.mid(2).join(" ");
                emit bridge.ipcTriggered(action, target, arg);
            }
        });
    });

    // ── Setup QQmlApplicationEngine ──────────────────────────────────────────
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("b1air", &bridge);
    engine.rootContext()->setContextProperty("Bridge", &bridge);

    // Locate Shell QML Entrypoint
    QString homePath = QDir::homePath();
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

    std::cout << "[b1air-shell] Native Qt6 Desktop Shell initialized successfully.\n";
    return app.exec();
}
