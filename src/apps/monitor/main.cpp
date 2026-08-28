// =============================================================================
// b1air-monitor — Native C++20 / Qt6 Activity Monitor & Task Manager
// Zero JSON • Direct C++ Models • Wayland Native
// =============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <iostream>
#include "backend.hpp"

int main(int argc, char* argv[]) {
    qputenv("QT_QPA_PLATFORM", "wayland;xcb");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "basic");
    qputenv("QML_DISABLE_DISK_CACHE", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-monitor");
    app.setApplicationDisplayName("System Monitor");
    app.setDesktopFileName("b1air-monitor");
    app.setOrganizationName("bla1r1");

    QQmlApplicationEngine engine;
    engine.addImportPath("/usr/lib/qt6/qml");

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath(home + "/.config/b1air-shell");

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-monitor QML] " << w.toString().toStdString() << "\n";
        }
    });

    b1air::MonitorBackend backend;
    engine.rootContext()->setContextProperty("MonitorBackend", &backend);

    QStringList searchPaths = {
        home + "/DotsFiles/src/apps/monitor/MonitorWindow.qml",
        home + "/DotsFiles/src/shell/qml/MonitorWindow.qml",
        home + "/.config/quickshell/MonitorWindow.qml",
        home + "/.config/b1air-shell/MonitorWindow.qml",
        "/usr/share/b1air-shell/qml/MonitorWindow.qml"
    };

    QString qmlPath;
    for (const auto& p : searchPaths) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (qmlPath.isEmpty()) {
        std::cerr << "[b1air-monitor] Error: MonitorWindow.qml not found!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-monitor] Error: Failed to load QML root object\n";
        return 1;
    }

    return app.exec();
}
