#include "git_backend.hpp"
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <iostream>

GitBackend::GitBackend(QObject* parent) : QObject(parent) {
    // Default to current directory or ~/DotsFiles
    QString initial = QDir::currentPath();
    if (!QDir(initial + "/.git").exists()) {
        initial = QDir::homePath() + "/DotsFiles";
    }
    openRepo(initial);
}

QString GitBackend::runGit(const QStringList& args, bool trim) {
    if (m_repoPath.isEmpty()) return "";
    QProcess proc;
    proc.setWorkingDirectory(m_repoPath);
    proc.start("git", args);
    // push/pull over the network routinely take longer than 5s.
    proc.waitForFinished(30000);

    QString out = QString::fromUtf8(proc.readAllStandardOutput());
    out = trim ? out.trimmed() : QString(out).remove(QRegularExpression("\\s+$"));
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        QString err = QString::fromUtf8(proc.readAllStandardError()).trimmed();
        if (err.isEmpty()) err = out;
        if (err.isEmpty()) err = "git " + args.join(' ') + " failed";
        emit commandFailed(err);
    }
    return out;
}

void GitBackend::openRepo(const QString& path) {
    QDir dir(path);
    while (!dir.isRoot() && !dir.exists(".git")) {
        if (!dir.cdUp()) break;
    }

    if (dir.exists(".git")) {
        m_repoPath = dir.absolutePath();
        m_isRepo = true;
    } else {
        m_repoPath = path;
        m_isRepo = false;
    }

    emit repoChanged();
    refresh();
}

void GitBackend::refresh() {
    updateBranch();
    updateStatus();
    updateHistory();
    updateDiff();
}

void GitBackend::updateBranch() {
    QString out = runGit(QStringList() << "branch" << "--show-current");
    m_branchName = out.isEmpty() ? "detached" : out;
    emit branchChanged();
}

void GitBackend::updateStatus() {
    QString out = runGit(QStringList() << "status" << "--porcelain=v1", false);
    m_changedFiles.clear();

    QStringList lines = out.split("\n", Qt::SkipEmptyParts);
    for (const auto& l : lines) {
        if (l.size() < 3) continue;
        QString xy = l.left(2);
        QString filePath = l.mid(2).trimmed();

        QVariantMap item;
        item["path"] = filePath;
        item["name"] = QFileInfo(filePath).fileName();

        char x = xy[0].toLatin1();
        char y = xy[1].toLatin1();

        item["isStaged"] = (x != ' ' && x != '?');
        
        QString status = "modified";
        if (x == 'A' || y == 'A' || x == '?' || y == '?') status = "added";
        else if (x == 'D' || y == 'D') status = "deleted";
        else if (x == 'R' || y == 'R') status = "renamed";
        
        item["status"] = status;
        item["code"] = xy.trimmed();

        m_changedFiles.append(item);
    }

    if (m_changedFiles.isEmpty()) {
        m_statusSummary = "Working tree clean";
        m_selectedFile = "";
    } else {
        m_statusSummary = QString::number(m_changedFiles.size()) + " files changed";
        if (m_selectedFile.isEmpty() || !out.contains(m_selectedFile)) {
            m_selectedFile = m_changedFiles[0].toMap()["path"].toString();
        }
    }

    emit statusChanged();
    emit selectedFileChanged();
}

void GitBackend::updateHistory() {
    QString out = runGit(QStringList() << "log" << "-n" << "20" << "--pretty=format:%h|%an|%cr|%s");
    m_commitHistory.clear();

    QStringList lines = out.split("\n", Qt::SkipEmptyParts);
    for (const auto& l : lines) {
        QStringList parts = l.split("|");
        if (parts.size() >= 4) {
            QVariantMap c;
            c["hash"] = parts[0];
            c["author"] = parts[1];
            c["date"] = parts[2];
            c["message"] = parts[3];
            m_commitHistory.append(c);
        }
    }
    emit historyChanged();
}

void GitBackend::selectFile(const QString& filePath) {
    m_selectedFile = filePath;
    emit selectedFileChanged();
    updateDiff();
}

void GitBackend::updateDiff() {
    m_currentDiff.clear();
    if (m_selectedFile.isEmpty()) {
        emit diffChanged();
        return;
    }

    QString out = runGit(QStringList() << "diff" << "HEAD" << "--" << m_selectedFile);
    if (out.isEmpty()) {
        out = runGit(QStringList() << "diff" << "--" << m_selectedFile);
    }
    if (out.isEmpty()) {
        // Untracked file: show file content as added lines
        QFile file(m_repoPath + "/" + m_selectedFile);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = QString::fromUtf8(file.readAll());
            QStringList fileLines = content.split("\n");
            for (int i = 0; i < fileLines.size(); ++i) {
                QVariantMap row;
                row["type"] = "add";
                row["newLine"] = i + 1;
                row["oldLine"] = "";
                row["text"] = "+" + fileLines[i];
                m_currentDiff.append(row);
            }
            emit diffChanged();
            return;
        }
    }

    QStringList lines = out.split("\n");
    int oldL = 1;
    int newL = 1;

    for (const auto& l : lines) {
        if (l.startsWith("diff --git") || l.startsWith("index ") || l.startsWith("--- ") || l.startsWith("+++ ")) {
            continue;
        }

        QVariantMap row;
        if (l.startsWith("@@")) {
            row["type"] = "header";
            row["text"] = l;
            row["oldLine"] = "";
            row["newLine"] = "";
            
            // Extract line numbers: @@ -old,count +new,count @@
            QRegularExpression re("@@ -([0-9]+).*\\+([0-9]+)");
            auto match = re.match(l);
            if (match.hasMatch()) {
                oldL = match.captured(1).toInt();
                newL = match.captured(2).toInt();
            }
        } else if (l.startsWith("+")) {
            row["type"] = "add";
            row["text"] = l;
            row["oldLine"] = "";
            row["newLine"] = newL++;
        } else if (l.startsWith("-")) {
            row["type"] = "del";
            row["text"] = l;
            row["oldLine"] = oldL++;
            row["newLine"] = "";
        } else {
            row["type"] = "ctx";
            row["text"] = l;
            row["oldLine"] = oldL++;
            row["newLine"] = newL++;
        }
        m_currentDiff.append(row);
    }

    emit diffChanged();
}

void GitBackend::stageFile(const QString& filePath) {
    runGit(QStringList() << "add" << filePath);
    refresh();
}

void GitBackend::unstageFile(const QString& filePath) {
    runGit(QStringList() << "restore" << "--staged" << filePath);
    refresh();
}

void GitBackend::stageAll() {
    runGit(QStringList() << "add" << "-A");
    refresh();
}

void GitBackend::commit(const QString& message) {
    if (message.trimmed().isEmpty()) return;
    runGit(QStringList() << "commit" << "-m" << message);
    refresh();
}

void GitBackend::push() {
    runGit(QStringList() << "push");
    refresh();
}

void GitBackend::pull() {
    runGit(QStringList() << "pull");
    refresh();
}
