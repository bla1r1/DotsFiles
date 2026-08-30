#pragma once

#include <QQuickPaintedItem>
#include <QFont>
#include <QFontMetricsF>
#include <QSocketNotifier>
#include <QColor>
#include <vterm.h>
#include <sys/types.h>
#include <deque>
#include <vector>

namespace b1air {

class TerminalItem : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged)
    Q_PROPERTY(int cols READ cols NOTIFY sizeChanged)
    Q_PROPERTY(int rows READ rows NOTIFY sizeChanged)

public:
    explicit TerminalItem(QQuickItem *parent = nullptr);
    ~TerminalItem() override;

    QString title() const { return m_title; }
    int fontSize() const { return m_fontSize; }
    void setFontSize(int size);

    QString fontFamily() const { return m_fontFamily; }
    void setFontFamily(const QString &family);

    int cols() const { return m_cols; }
    int rows() const { return m_rows; }

    Q_INVOKABLE void sendText(const QString &text);
    Q_INVOKABLE void copySelection();
    Q_INVOKABLE void pasteClipboard();
    Q_INVOKABLE void zoomIn();
    Q_INVOKABLE void zoomOut();
    Q_INVOKABLE void resetZoom();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void launch(const QString &command = QString(), const QString &workingDir = QString());

signals:
    void titleChanged();
    void fontSizeChanged();
    void fontFamilyChanged();
    void sizeChanged();
    void processFinished(int exitCode);

protected:
    void paint(QPainter *painter) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void keyPressEvent(QKeyEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void wheelEvent(QWheelEvent *event) override;

private slots:
    void onPtyRead();

private:
    void initTerminal(int rows, int cols);
    void updateFontMetrics();
    void updatePtySize();
    QColor toQColor(const VTermColor &color, const QColor &defaultColor) const;

    // libvterm callbacks
    static int cbDamage(VTermRect rect, void *user);
    static int cbMoverect(VTermRect dest, VTermRect src, void *user);
    static int cbMovecursor(VTermPos pos, VTermPos oldpos, int visible, void *user);
    static int cbSettermprop(VTermProp prop, VTermValue *val, void *user);
    static int cbBell(void *user);
    static int cbResize(int rows, int cols, void *user);
    static int cbSbPushline(int cols, const VTermScreenCell *cells, void *user);
    static int cbSbPopline(int cols, VTermScreenCell *cells, void *user);
    static void cbOutput(const char *s, size_t len, void *user);

    VTermScreenCallbacks m_screenCallbacks = {};

    int m_masterFd = -1;
    pid_t m_childPid = -1;

    VTerm *m_vt = nullptr;
    VTermScreen *m_vts = nullptr;
    QSocketNotifier *m_notifier = nullptr;

    QFont m_font;
    qreal m_cellWidth = 10.0;
    qreal m_cellHeight = 20.0;
    qreal m_fontAscent = 15.0;

    int m_cols = 80;
    int m_rows = 24;
    int m_fontSize = 11;
    QString m_fontFamily = "JetBrainsMono Nerd Font Mono";
    QString m_title = "Terminal";

    VTermPos m_cursorPos = {0, 0};
    bool m_cursorVisible = true;

    bool m_selecting = false;
    VTermPos m_selStart = {0, 0};
    VTermPos m_selEnd = {0, 0};
    bool m_hasSelection = false;

    std::deque<std::vector<VTermScreenCell>> m_scrollback;
    int m_viewOffset = 0;
};

} // namespace b1air
