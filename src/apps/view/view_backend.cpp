#include "view_backend.hpp"
#include <QDateTime>
#include <QProcess>
#include <iostream>

ViewBackend::ViewBackend(QObject* parent) : QObject(parent) {}

void ViewBackend::openFile(const QString& filePath) {
    QFileInfo fi(filePath);
    if (!fi.exists() || !fi.isFile()) return;

    m_currentPath = fi.absoluteFilePath();
    scanDirectory(fi.absolutePath(), m_currentPath);
    updateFileInfo();
}

void ViewBackend::scanDirectory(const QString& dirPath, const QString& currentFile) {
    QDir dir(dirPath);
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp" << "*.gif" << "*.bmp" << "*.svg";
    
    dir.setNameFilters(filters);
    dir.setFilter(QDir::Files | QDir::NoSymLinks);
    dir.setSorting(QDir::Name);

    QFileInfoList list = dir.entryInfoList();
    m_imageList.clear();
    m_filesInDir.clear();
    m_currentIndex = -1;

    for (int i = 0; i < list.size(); ++i) {
        QString path = list[i].absoluteFilePath();
        m_imageList.append(path);
        
        QVariantMap item;
        item["path"] = path;
        item["name"] = list[i].fileName();
        item["size"] = QString::number(list[i].size() / 1024) + " KB";
        m_filesInDir.append(item);

        if (path == currentFile) {
            m_currentIndex = i;
        }
    }

    if (m_currentIndex == -1 && !m_imageList.isEmpty()) {
        m_currentIndex = 0;
        m_currentPath = m_imageList[0];
    }

    emit directoryChanged();
}

void ViewBackend::updateFileInfo() {
    if (m_currentPath.isEmpty()) return;

    QFileInfo fi(m_currentPath);
    m_fileName = fi.fileName();
    
    qint64 bytes = fi.size();
    if (bytes > 1024 * 1024) {
        m_fileSize = QString::number(bytes / (1024.0 * 1024.0), 'f', 2) + " MB";
    } else {
        m_fileSize = QString::number(bytes / 1024.0, 'f', 1) + " KB";
    }

    QImageReader reader(m_currentPath);
    QSize sz = reader.size();
    if (sz.isValid()) {
        m_resolution = QString("%1 × %2").arg(sz.width()).arg(sz.height());
    } else {
        m_resolution = "Unknown";
    }

    emit currentPathChanged();
    emit fileChanged();
}

void ViewBackend::next() {
    if (hasNext()) {
        m_currentIndex++;
        m_currentPath = m_imageList[m_currentIndex];
        updateFileInfo();
    }
}

void ViewBackend::previous() {
    if (hasPrevious()) {
        m_currentIndex--;
        m_currentPath = m_imageList[m_currentIndex];
        updateFileInfo();
    }
}

void ViewBackend::setWallpaper() {
    if (m_currentPath.isEmpty()) return;
    // Was: a "wallpaper <path>" call the daemon does not accept (the verb is
    // "wallpaper set <path>"), plus a raw swaybg spawn that stacked a new
    // instance on every use without killing the previous one.
    QProcess::startDetached("b1air-daemon", QStringList() << "wallpaper" << "set" << m_currentPath);
}

QVariantMap ViewBackend::getMetadata() {
    QVariantMap meta;
    if (m_currentPath.isEmpty()) return meta;

    QFileInfo fi(m_currentPath);
    meta["fileName"] = fi.fileName();
    meta["path"] = fi.absoluteFilePath();
    meta["size"] = m_fileSize;
    meta["resolution"] = m_resolution;
    meta["created"] = fi.birthTime().toString("yyyy-MM-dd HH:mm:ss");
    meta["modified"] = fi.lastModified().toString("yyyy-MM-dd HH:mm:ss");

    QImageReader reader(m_currentPath);
    meta["format"] = QString::fromLatin1(reader.format()).toUpper();

    return meta;
}
