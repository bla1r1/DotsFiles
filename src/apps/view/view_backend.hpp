#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QImageReader>
#include <QFileInfo>
#include <QDir>

class ViewBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileChanged)
    Q_PROPERTY(QString fileSize READ fileSize NOTIFY fileChanged)
    Q_PROPERTY(QString imageResolution READ imageResolution NOTIFY fileChanged)
    Q_PROPERTY(int fileIndex READ fileIndex NOTIFY fileChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY fileChanged)
    Q_PROPERTY(bool hasPrevious READ hasPrevious NOTIFY fileChanged)
    Q_PROPERTY(bool hasNext READ hasNext NOTIFY fileChanged)
    Q_PROPERTY(QVariantList filesInDir READ filesInDir NOTIFY directoryChanged)

public:
    explicit ViewBackend(QObject* parent = nullptr);

    QString currentPath() const { return m_currentPath; }
    QString fileName() const { return m_fileName; }
    QString fileSize() const { return m_fileSize; }
    QString imageResolution() const { return m_resolution; }
    int fileIndex() const { return m_currentIndex; }
    int totalFiles() const { return m_imageList.size(); }
    bool hasPrevious() const { return m_currentIndex > 0; }
    bool hasNext() const { return m_currentIndex >= 0 && m_currentIndex < m_imageList.size() - 1; }
    QVariantList filesInDir() const { return m_filesInDir; }

    Q_INVOKABLE void openFile(const QString& filePath);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void setWallpaper();
    Q_INVOKABLE QVariantMap getMetadata();

signals:
    void currentPathChanged();
    void fileChanged();
    void directoryChanged();

private:
    void scanDirectory(const QString& dirPath, const QString& currentFile);
    void updateFileInfo();

    QString m_currentPath;
    QString m_fileName;
    QString m_fileSize;
    QString m_resolution;
    int m_currentIndex = -1;
    QStringList m_imageList;
    QVariantList m_filesInDir;
};
