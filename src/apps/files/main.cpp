// =============================================================================
// b1air-files — Native C++20 / Qt6 File Manager & Gallery Application
// =============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <iostream>
#include "backend.hpp"

int main(int argc, char* argv[]) {
    qputenv("QT_QPA_PLATFORM", "wayland;xcb");
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "basic");
    qputenv("QML_DISABLE_DISK_CACHE", "0");

    QGuiApplication app(argc, argv);
    app.setApplicationName("b1air-files");
    app.setApplicationDisplayName("Files");
    app.setDesktopFileName("b1air-files");
    app.setOrganizationName("bla1r1");

    QQmlApplicationEngine engine;
    engine.addImportPath("/usr/lib/qt6/qml");

    QString home = QDir::homePath();
    engine.addImportPath(home + "/DotsFiles/src/shell/qml");
    engine.addImportPath(home + "/.config/quickshell");
    engine.addImportPath(home + "/.config/b1air-shell");

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& w : warnings) {
            std::cerr << "[b1air-files QML] " << w.toString().toStdString() << "\n";
        }
    });

    b1air::FileManagerBackend backend;
    if (argc > 1) {
        // Desktop entries use %U, so callers (Firefox "Open Containing
        // Folder", xdg-open, etc.) pass a file:// URI, not a bare path.
        QUrl url(QString::fromUtf8(argv[1]));
        QString targetPath = url.isLocalFile() ? url.toLocalFile() : url.toString();

        QFileInfo fi(targetPath);
        if (fi.isDir()) {
            backend.setCurrentPath(fi.absoluteFilePath());
        } else if (fi.exists()) {
            // A specific file (e.g. a just-downloaded file) was passed:
            // land in its containing folder instead of doing nothing.
            backend.setCurrentPath(fi.absolutePath());
        }
    }
    engine.rootContext()->setContextProperty("FilesBackend", &backend);

    QStringList searchPaths = {
        // shell/qml is the actively maintained copy; apps/files's has quietly
        // diverged from it (missed every fix made against the shell copy).
        home + "/DotsFiles/src/shell/qml/FilesWindow.qml",
        home + "/DotsFiles/src/apps/files/FilesWindow.qml",
        home + "/.config/quickshell/FilesWindow.qml",
        home + "/.config/b1air-shell/FilesWindow.qml",
        "/usr/share/b1air-shell/qml/FilesWindow.qml"
    };

    QString qmlPath;
    for (const auto& p : searchPaths) {
        if (QFile::exists(p)) {
            qmlPath = p;
            break;
        }
    }

    if (qmlPath.isEmpty()) {
        std::cerr << "[b1air-files] Error: FilesWindow.qml not found!\n";
        return 1;
    }

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[b1air-files] Error: Failed to load FilesWindow.qml\n";
        return -1;
    }

    return app.exec();
}
