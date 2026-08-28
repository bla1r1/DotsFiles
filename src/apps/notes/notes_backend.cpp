#include "notes_backend.hpp"
#include <QDateTime>
#include <QTextStream>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QUuid>
#include <iostream>

NotesBackend::NotesBackend(QObject* parent) : QObject(parent) {
    ensureStorageDir();
    loadConfig();
    loadNotes();
}

void NotesBackend::ensureStorageDir() {
    m_storageDir = QDir::homePath() + "/.local/share/b1air-notes";
    QDir dir(m_storageDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    if (m_obsidianVault.isEmpty()) {
        QString defaultObs = QDir::homePath() + "/Documents/Obsidian";
        QDir obsDir(defaultObs);
        if (obsDir.exists()) {
            m_obsidianVault = defaultObs;
        }
    }
}

void NotesBackend::loadConfig() {
    QFile file(m_storageDir + "/config.json");
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        QJsonObject obj = doc.object();
        m_obsidianVault = obj["obsidianVault"].toString();
        m_notionToken = obj["notionToken"].toString();
        m_notionDbId = obj["notionDbId"].toString();
    }
}

void NotesBackend::saveConfig() {
    QJsonObject obj;
    obj["obsidianVault"] = m_obsidianVault;
    obj["notionToken"] = m_notionToken;
    obj["notionDbId"] = m_notionDbId;

    QFile file(m_storageDir + "/config.json");
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(obj).toJson());
    }
}

QVariantList NotesBackend::noteList() const {
    QVariantList list;
    for (const auto& n : m_notes) {
        QVariantMap map;
        map["id"] = n.id;
        map["title"] = n.title;
        map["content"] = n.content;
        map["tags"] = n.tags;
        map["modified"] = n.modified;
        map["source"] = n.source;
        map["snippet"] = n.content.left(80).replace("\n", " ");
        list.append(map);
    }
    return list;
}

QString NotesBackend::currentTitle() const {
    for (const auto& n : m_notes) {
        if (n.id == m_currentId) return n.title;
    }
    return "";
}

QString NotesBackend::currentContent() const {
    for (const auto& n : m_notes) {
        if (n.id == m_currentId) return n.content;
    }
    return "";
}

QString NotesBackend::currentTags() const {
    for (const auto& n : m_notes) {
        if (n.id == m_currentId) return n.tags.join(", ");
    }
    return "";
}

void NotesBackend::loadNotes() {
    m_notes.clear();

    // 1. Scan Local Notes Directory
    QDir localDir(m_storageDir + "/notes");
    if (!localDir.exists()) localDir.mkpath(".");

    QFileInfoList localFiles = localDir.entryInfoList(QStringList() << "*.md", QDir::Files, QDir::Time);
    for (const auto& fi : localFiles) {
        QFile file(fi.absoluteFilePath());
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            QString content = in.readAll();
            
            NoteItem note;
            note.id = fi.baseName();
            note.title = fi.baseName();
            note.content = content;
            note.modified = fi.lastModified().toString("MMM d, hh:mm");
            note.source = "local";
            note.filePath = fi.absoluteFilePath();
            
            // Extract tags e.g. #ideas #todo
            QRegularExpression tagRe("#([a-zA-Z0-9_-]+)");
            auto matchIt = tagRe.globalMatch(content);
            while (matchIt.hasNext()) {
                note.tags.append(matchIt.next().captured(0));
            }

            m_notes.append(note);
        }
    }

    // 2. Scan Obsidian Vault if exists
    if (!m_obsidianVault.isEmpty() && QDir(m_obsidianVault).exists()) {
        scanObsidianVault();
    }

    // If empty, create a welcome note
    if (m_notes.isEmpty()) {
        createNote("Getting Started with b1air-notes");
    } else if (m_currentId.isEmpty()) {
        m_currentId = m_notes[0].id;
    }

    emit notesChanged();
    emit currentNoteChanged();
}

void NotesBackend::scanObsidianVault() {
    QDir obsDir(m_obsidianVault);
    QFileInfoList files = obsDir.entryInfoList(QStringList() << "*.md", QDir::Files, QDir::Time);
    for (const auto& fi : files) {
        QFile file(fi.absoluteFilePath());
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&file);
            QString content = in.readAll();

            NoteItem note;
            note.id = "obs_" + fi.baseName();
            note.title = fi.baseName();
            note.content = content;
            note.modified = fi.lastModified().toString("MMM d, hh:mm");
            note.source = "obsidian";
            note.filePath = fi.absoluteFilePath();

            QRegularExpression tagRe("#([a-zA-Z0-9_-]+)");
            auto matchIt = tagRe.globalMatch(content);
            while (matchIt.hasNext()) {
                note.tags.append(matchIt.next().captured(0));
            }

            m_notes.append(note);
        }
    }
}

void NotesBackend::selectNote(const QString& id) {
    m_currentId = id;
    emit currentNoteChanged();
}

void NotesBackend::createNote(const QString& title) {
    NoteItem note;
    note.id = "note_" + QString::number(QDateTime::currentSecsSinceEpoch());
    note.title = title.isEmpty() ? "Untitled Note" : title;
    note.content = "# " + note.title + "\n\nStart writing notes, ideas, or todo lists here...\n\n- [ ] Task 1\n- [ ] Task 2\n\n#ideas #b1air";
    note.tags << "#ideas" << "#b1air";
    note.modified = QDateTime::currentDateTime().toString("MMM d, hh:mm");
    note.source = "local";
    note.filePath = m_storageDir + "/notes/" + note.id + ".md";

    QFile file(note.filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << note.content;
    }

    m_notes.prepend(note);
    m_currentId = note.id;

    emit notesChanged();
    emit currentNoteChanged();
}

void NotesBackend::saveCurrentNote(const QString& title, const QString& content, const QString& tags) {
    for (auto& n : m_notes) {
        if (n.id == m_currentId) {
            n.title = title;
            n.content = content;
            n.tags = tags.split(",", Qt::SkipEmptyParts);
            for (auto& t : n.tags) t = t.trimmed();
            n.modified = QDateTime::currentDateTime().toString("MMM d, hh:mm");

            // Write to file
            if (!n.filePath.isEmpty()) {
                QFile file(n.filePath);
                if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                    QTextStream out(&file);
                    out << content;
                }
            }
            break;
        }
    }

    emit notesChanged();
    emit currentNoteChanged();
}

void NotesBackend::deleteNote(const QString& id) {
    for (int i = 0; i < m_notes.size(); ++i) {
        if (m_notes[i].id == id) {
            if (!m_notes[i].filePath.isEmpty()) {
                QFile::remove(m_notes[i].filePath);
            }
            m_notes.removeAt(i);
            break;
        }
    }

    if (!m_notes.isEmpty()) {
        m_currentId = m_notes[0].id;
    } else {
        m_currentId = "";
    }

    emit notesChanged();
    emit currentNoteChanged();
}

void NotesBackend::setObsidianVault(const QString& path) {
    m_obsidianVault = path;
    saveConfig();
    emit obsidianVaultChanged();
    loadNotes();
}

void NotesBackend::setNotionCredentials(const QString& token, const QString& dbId) {
    m_notionToken = token;
    m_notionDbId = dbId;
    saveConfig();
    emit notionConfigChanged();
}

void NotesBackend::syncWithObsidian() {
    m_syncStatus = "Syncing Obsidian...";
    emit syncStatusChanged();
    loadNotes();
    m_syncStatus = "Obsidian Synced";
    emit syncStatusChanged();
}

void NotesBackend::syncWithNotion() {
    if (!isNotionConfigured()) {
        m_syncStatus = "Notion API token not configured";
        emit syncStatusChanged();
        return;
    }

    m_syncStatus = "Syncing with Notion API...";
    emit syncStatusChanged();

    QUrl url("https://api.notion.com/v1/databases/" + m_notionDbId + "/query");
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", ("Bearer " + m_notionToken).toUtf8());
    req.setRawHeader("Notion-Version", "2022-06-28");

    QNetworkReply* reply = m_netManager.post(req, "{}");
    connect(reply, &QNetworkReply::finished, [this, reply]() {
        if (reply->error() == QNetworkReply::NoError) {
            m_syncStatus = "Notion Synced";
        } else {
            m_syncStatus = "Notion Sync Error: " + reply->errorString();
        }
        emit syncStatusChanged();
        reply->deleteLater();
    });
}

QString NotesBackend::renderMarkdownToHtml(const QString& markdown) {
    QString html = markdown;
    // HTML escape
    html.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");

    // Headers
    html.replace(QRegularExpression("^### (.*)$", QRegularExpression::MultilineOption), "<h3 style='color:#7dcfff;margin:8px 0;'>\\1</h3>");
    html.replace(QRegularExpression("^## (.*)$", QRegularExpression::MultilineOption), "<h2 style='color:#bb9af7;margin:10px 0;'>\\1</h2>");
    html.replace(QRegularExpression("^# (.*)$", QRegularExpression::MultilineOption), "<h1 style='color:#7aa2f7;margin:12px 0;border-bottom:1px solid rgba(122,162,247,0.2);padding-bottom:4px;'>\\1</h1>");

    // Checkboxes
    html.replace(QRegularExpression("^- \\[x\\] (.*)$", QRegularExpression::MultilineOption), "<p style='color:#a9b1d6;margin:4px 0;'><span style='color:#73daca;'>☑</span> <strike>\\1</strike></p>");
    html.replace(QRegularExpression("^- \\[ \\] (.*)$", QRegularExpression::MultilineOption), "<p style='color:#c0caf5;margin:4px 0;'><span style='color:#7aa2f7;'>☐</span> \\1</p>");

    // Bullets
    html.replace(QRegularExpression("^- (.*)$", QRegularExpression::MultilineOption), "<li style='color:#c0caf5;margin:2px 0;'>\\1</li>");

    // Bold & Italic
    html.replace(QRegularExpression("\\*\\*(.*?)\\*\\*"), "<strong style='color:#ffffff;'>\\1</strong>");
    html.replace(QRegularExpression("\\*(.*?)\\*"), "<em style='color:#bb9af7;'>\\1</em>");

    // Code blocks
    html.replace(QRegularExpression("```([a-zA-Z]*)\n([\\s\\S]*?)```"), "<pre style='background:#16161e;padding:8px;border-radius:6px;color:#73daca;font-family:monospace;border:1px solid rgba(122,162,247,0.2);'><code>\\2</code></pre>");
    html.replace(QRegularExpression("`([^`]+)`"), "<code style='background:#24283b;padding:2px 6px;border-radius:4px;color:#ff9e64;font-family:monospace;'>\\1</code>");

    // Tags
    html.replace(QRegularExpression("#([a-zA-Z0-9_-]+)"), "<span style='background:rgba(122,162,247,0.15);color:#7aa2f7;padding:2px 6px;border-radius:4px;font-size:11px;'>#\\1</span>");

    // Newlines to <br>
    html.replace("\n", "<br/>");

    return "<div style='font-family:sans-serif;color:#c0caf5;font-size:13px;line-height:1.6;'>" + html + "</div>";
}
