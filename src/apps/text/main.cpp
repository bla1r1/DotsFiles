// =============================================================================
// b1air-text — Native C++20 / Qt6 Minimal Text & Config Editor
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
    app.setApplicationName("b1air-text");
    app.setApplicationDisplayName("Text Editor");
    app.setDesktopFileName("b1air-text");
    app.setOrganizationName("bla1r1");

    QQmlApplicationEngine engine;
    engine.addImportPath("/usr/lib/qt6/qml");

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath(home + "/.config/b1air-shell");

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-text QML] " << w.toString().toStdString() << "\n";
        }
    });

    b1air::TextBackend backend;
    if (argc > 1) {
        QString fileArg = QString::fromUtf8(argv[1]);
        backend.openFile(fileArg);
    }
    engine.rootContext()->setContextProperty("TextBackend", &backend);

    QStringList searchPaths = {
        // shell/qml is the actively maintained copy; apps/text's has quietly
        // diverged from it (missed every fix made against the shell copy).
        home + "/DotsFiles/src/shell/qml/TextWindow.qml",
        home + "/DotsFiles/src/apps/text/TextWindow.qml",
        home + "/.config/quickshell/TextWindow.qml",
        home + "/.config/b1air-shell/TextWindow.qml",
        "/usr/share/b1air-shell/qml/TextWindow.qml"
    };

    QString qmlPath;
    for (const auto& p : searchPaths) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (qmlPath.isEmpty()) {
        std::cerr << "[b1air-text] Error: TextWindow.qml not found!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-text] Error: Failed to load QML root object\n";
        return 1;
    }

    return app.exec();
}
