#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <iostream>
#include "calc_engine.hpp"

int main(int argc, char* argv[]) {
    // Force Wayland, high performance rendering & basic render loop (0% idle CPU)
    setenv("QT_QPA_PLATFORM", "wayland;xcb", 1);
    setenv("QSG_RHI_BACKEND", "opengl", 1);
    setenv("QSG_RENDER_LOOP", "basic", 1);
    setenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1", 1);

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-calc");
    app.setOrganizationName("b1air");

    CalcEngine calcEngine;

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[QML Warning] " << w.toString().toStdString() << "\n";
        }
    });
    engine.rootContext()->setContextProperty("CalcEngine", &calcEngine);

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath("/usr/lib/qt6/qml");

    QString qmlPath = home + "/DotsFiles/src/apps/calc/CalcWindow.qml";
    if (!QFile::exists(qmlPath)) {
        qmlPath = "/usr/share/b1air-calc/CalcWindow.qml";
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-calc] Error: Failed to load QML root component\n";
        return 1;
    }

    return app.exec();
}
