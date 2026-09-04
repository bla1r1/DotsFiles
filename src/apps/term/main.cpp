// =============================================================================
// b1air-term — Native C++20 / Qt6 Desktop Terminal Emulator
// Zero JSON • libvterm • Wayland Native
// =============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <iostream>
#include "terminal_item.hpp"

int main(int argc, char* argv[]) {
    qputenv("QT_QPA_PLATFORM", "wayland;xcb");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "basic");
    qputenv("QML_DISABLE_DISK_CACHE", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-term");
    app.setApplicationDisplayName("Terminal");
    app.setDesktopFileName("b1air-term");
    app.setOrganizationName("bla1r1");

    qmlRegisterType<b1air::TerminalItem>("B1Air.Term", 1, 0, "TerminalView");

    QQmlApplicationEngine engine;
    engine.addImportPath("/usr/lib/qt6/qml");

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath(home + "/.config/b1air-shell");

    QString initialCommand = "";
    QString initialDir = "";

    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromUtf8(argv[i]);
        if (arg == "-e" && i + 1 < argc) {
            QStringList cmdParts;
            for (int j = i + 1; j < argc; ++j) {
                cmdParts << QString::fromUtf8(argv[j]);
            }
            initialCommand = cmdParts.join(" ");
            break;
        } else if (QDir(arg).exists()) {
            initialDir = QDir(arg).canonicalPath();
        }
    }

    engine.rootContext()->setContextProperty("InitialCommand", initialCommand);
    engine.rootContext()->setContextProperty("InitialDir", initialDir);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-term QML] " << w.toString().toStdString() << "\n";
        }
    });

    QStringList searchPaths = {
        // shell/qml is the actively maintained copy; apps/term's has quietly
        // diverged from it (missed every fix made against the shell copy).
        home + "/DotsFiles/src/shell/qml/TermWindow.qml",
        home + "/DotsFiles/src/apps/term/TermWindow.qml",
        home + "/.config/quickshell/TermWindow.qml",
        home + "/.config/b1air-shell/TermWindow.qml",
        "/usr/share/b1air-shell/qml/TermWindow.qml"
    };

    QString qmlPath;
    for (const auto& p : searchPaths) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (qmlPath.isEmpty()) {
        std::cerr << "[b1air-term] Error: TermWindow.qml not found!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-term] Error: Failed to load TermWindow.qml\n";
        return 1;
    }

    return app.exec();
}
