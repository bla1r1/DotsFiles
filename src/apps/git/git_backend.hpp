#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QProcess>

class GitBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString repoPath READ repoPath NOTIFY repoChanged)
    Q_PROPERTY(bool isRepo READ isRepo NOTIFY repoChanged)
    Q_PROPERTY(QString branchName READ branchName NOTIFY branchChanged)
    Q_PROPERTY(QString statusSummary READ statusSummary NOTIFY statusChanged)
    Q_PROPERTY(QString selectedFile READ selectedFile NOTIFY selectedFileChanged)
    Q_PROPERTY(QVariantList changedFiles READ changedFiles NOTIFY statusChanged)
    Q_PROPERTY(QVariantList commitHistory READ commitHistory NOTIFY historyChanged)
    Q_PROPERTY(QVariantList currentDiff READ currentDiff NOTIFY diffChanged)

public:
    explicit GitBackend(QObject* parent = nullptr);

    QString repoPath() const { return m_repoPath; }
    bool isRepo() const { return m_isRepo; }
    QString branchName() const { return m_branchName; }
    QString statusSummary() const { return m_statusSummary; }
    QString selectedFile() const { return m_selectedFile; }
    QVariantList changedFiles() const { return m_changedFiles; }
    QVariantList commitHistory() const { return m_commitHistory; }
    QVariantList currentDiff() const { return m_currentDiff; }

    Q_INVOKABLE void openRepo(const QString& path);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectFile(const QString& filePath);
    Q_INVOKABLE void stageFile(const QString& filePath);
    Q_INVOKABLE void unstageFile(const QString& filePath);
    Q_INVOKABLE void stageAll();
    Q_INVOKABLE void commit(const QString& message);
    Q_INVOKABLE void push();
    Q_INVOKABLE void pull();

signals:
    void repoChanged();
    void branchChanged();
    void statusChanged();
    void selectedFileChanged();
    void historyChanged();
    void diffChanged();
    // git failures used to be swallowed whole: runGit() read stdout only
    // and ignored the exit code, so a rejected push looked like a no-op.
    void commandFailed(const QString& message);

private:
    // trim=false for output whose leading whitespace is significant:
    // git status --porcelain encodes state in two columns, and a leading
    // space means "not staged". Trimming ate it on the first line, so the
    // top unstaged file read as staged and its button called unstage.
    QString runGit(const QStringList& args, bool trim = true);
    bool m_isRepo = false;
    void updateBranch();
    void updateStatus();
    void updateHistory();
    void updateDiff();

    QString m_repoPath;
    QString m_branchName = "main";
    QString m_statusSummary = "Clean";
    QString m_selectedFile;
    QVariantList m_changedFiles;
    QVariantList m_commitHistory;
    QVariantList m_currentDiff;
};
