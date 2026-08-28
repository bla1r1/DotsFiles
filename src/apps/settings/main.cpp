// =============================================================================
// b1air-settings — Native C++20 / Qt6 Desktop Settings Application
// Zero JSON • Direct C++ Engine • Wayland Native
// =============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <iostream>

int main(int argc, char* argv[]) {
    qputenv("QT_QPA_PLATFORM", "wayland;xcb");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "basic");
    qputenv("QML_DISABLE_DISK_CACHE", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-settings");
    app.setApplicationDisplayName("System Settings");
    app.setDesktopFileName("b1air-settings");
    app.setOrganizationName("bla1r1");

    QQmlApplicationEngine engine;
    engine.addImportPath("/usr/lib/qt6/qml");

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath(home + "/.config/b1air-shell");

    QString initialPage = "";
    if (argc > 1) {
        initialPage = QString::fromUtf8(argv[1]);
    }
    engine.rootContext()->setContextProperty("InitialSettingsPage", initialPage);

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-settings QML] " << w.toString().toStdString() << "\n";
        }
    });

    QStringList searchPaths = {
        home + "/DotsFiles/src/apps/settings/SettingsWindow.qml",
        home + "/DotsFiles/src/shell/qml/SettingsWindow.qml",
        home + "/.config/quickshell/SettingsWindow.qml",
        home + "/.config/b1air-shell/SettingsWindow.qml",
        "/usr/share/b1air-shell/qml/SettingsWindow.qml"
    };

    QString qmlPath;
    for (const auto& p : searchPaths) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (qmlPath.isEmpty()) {
        std::cerr << "[b1air-settings] Error: SettingsWindow.qml not found!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-settings] Error: Failed to load SettingsWindow.qml\n";
        return 1;
    }

    return app.exec();
}
