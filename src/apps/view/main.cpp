#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <iostream>
#include "view_backend.hpp"

int main(int argc, char* argv[]) {
    // Force Wayland, high performance rendering & basic render loop (0% idle CPU)
    setenv("QT_QPA_PLATFORM", "wayland;xcb", 1);
    setenv("QSG_RHI_BACKEND", "opengl", 1);
    setenv("QSG_RENDER_LOOP", "basic", 1);
    setenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1", 1);

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-view");
    app.setOrganizationName("b1air");

    ViewBackend viewBackend;

    // Check CLI argument for initial file
    QString initialFile = "";
    if (argc > 1) {
        initialFile = QString::fromUtf8(argv[1]);
    } else {
        QStringList candidates = {
            QDir::homePath() + "/Pictures",
            QDir::homePath() + "/Pictures/Wallpapers",
            QDir::homePath() + "/DotsFiles/wallpapers",
            QDir::currentPath()
        };
        for (const auto& c : candidates) {
            QDir d(c);
            if (d.exists()) {
                QFileInfoList list = d.entryInfoList(QStringList() << "*.png" << "*.jpg" << "*.jpeg" << "*.webp", QDir::Files);
                if (!list.isEmpty()) {
                    initialFile = list[0].absoluteFilePath();
                    break;
                }
            }
        }
    }

    if (!initialFile.isEmpty()) {
        viewBackend.openFile(initialFile);
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-view QML Warning] " << w.toString().toStdString() << "\n";
        }
    });

    engine.rootContext()->setContextProperty("ViewBackend", &viewBackend);

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath("/usr/lib/qt6/qml");

    QString qmlPath = home + "/DotsFiles/src/apps/view/ViewWindow.qml";
    if (!QFile::exists(qmlPath)) {
        qmlPath = "/usr/share/b1air-view/ViewWindow.qml";
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-view] Error: Failed to load QML root component\n";
        return 1;
    }

    return app.exec();
}
