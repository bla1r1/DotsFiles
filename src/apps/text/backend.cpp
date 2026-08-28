#include "backend.hpp"

#include <QRegularExpression>

namespace b1air {

TextBackend::TextBackend(QObject* parent)
    : QObject(parent)
{
    updateStats();
}

void TextBackend::setFileContent(const QString& content) {
    if (m_content != content) {
        m_content = content;
        m_isModified = true;
        updateStats();
        emit contentChanged();
        emit modifiedChanged();
    }
}

void TextBackend::setIsModified(bool mod) {
    if (m_isModified != mod) {
        m_isModified = mod;
        emit modifiedChanged();
    }
}

bool TextBackend::openFile(const QString& path) {
    QString cleanPath = path;
    if (cleanPath.startsWith("file://")) {
        cleanPath = cleanPath.mid(7);
    }

    QFile file(cleanPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream in(&file);
    m_content = in.readAll();
    m_filePath = cleanPath;
    QFileInfo fi(cleanPath);
    m_fileName = fi.fileName();
    m_isModified = false;

    detectFileType();
    updateStats();

    emit fileChanged();
    emit contentChanged();
    emit modifiedChanged();
    return true;
}

bool TextBackend::saveFile(const QString& path) {
    QString targetPath = path.isEmpty() ? m_filePath : path;
    if (targetPath.startsWith("file://")) {
        targetPath = targetPath.mid(7);
    }
    if (targetPath.isEmpty()) {
        return false;
    }

    QFile file(targetPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return false;
    }

    QTextStream out(&file);
    out << m_content;
    file.close();

    m_filePath = targetPath;
    QFileInfo fi(targetPath);
    m_fileName = fi.fileName();
    m_isModified = false;

    detectFileType();
    emit fileChanged();
    emit modifiedChanged();
    return true;
}

void TextBackend::newFile() {
    m_filePath.clear();
    m_fileName = "Untitled";
    m_content.clear();
    m_isModified = false;
    m_fileType = "Plain Text";
    updateStats();

    emit fileChanged();
    emit contentChanged();
    emit modifiedChanged();
}

void TextBackend::updateStats() {
    m_lineCount = m_content.count('\n') + 1;
    if (m_content.isEmpty()) {
        m_wordCount = 0;
    } else {
        auto words = m_content.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        m_wordCount = words.size();
    }
    emit statsChanged();
}

void TextBackend::detectFileType() {
    if (m_filePath.isEmpty()) {
        m_fileType = "Plain Text";
        return;
    }

    QFileInfo fi(m_filePath);
    QString ext = fi.suffix().toLower();
    QString name = fi.fileName().toLower();

    if (ext == "cpp" || ext == "hpp" || ext == "cc" || ext == "c" || ext == "h") m_fileType = "C/C++";
    else if (ext == "py") m_fileType = "Python";
    else if (ext == "sh" || ext == "bash" || ext == "zsh") m_fileType = "Shell Script";
    else if (ext == "qml") m_fileType = "QML";
    else if (ext == "js" || ext == "ts") m_fileType = "JavaScript";
    else if (ext == "rs") m_fileType = "Rust";
    else if (ext == "json") m_fileType = "JSON";
    else if (ext == "md" || ext == "markdown") m_fileType = "Markdown";
    else if (ext == "conf" || ext == "ini" || ext == "cfg") m_fileType = "Configuration";
    else if (ext == "yaml" || ext == "yml") m_fileType = "YAML";
    else if (ext == "toml") m_fileType = "TOML";
    else if (ext == "html" || ext == "htm") m_fileType = "HTML";
    else if (ext == "css") m_fileType = "CSS";
    else if (name == "makefile" || name == "cmakelists.txt") m_fileType = "Build Script";
    else m_fileType = "Plain Text";
}

} // namespace b1air
