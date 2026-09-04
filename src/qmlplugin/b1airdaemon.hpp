#pragma once

// =============================================================================
// B1air.Daemon — the running daemon, exposed to QML directly.
//
// The shell used to reach the daemon by spawning `b1air-daemon <verb>`: a
// process per click, with the exit code thrown away, so a failed action was
// indistinguishable from a successful one. The daemon has published a D-Bus
// interface the whole time; this is that interface, as a QML singleton.
//
// Calls are asynchronous and never block the UI thread. A call that fails
// emits failed(), which is the part the subprocess route could not provide.
// =============================================================================

#include <QObject>
#include <QString>
#include <QDBusConnection>

class B1airDaemon : public QObject {
    Q_OBJECT

    // False when the daemon is not on the bus, so the UI can disable controls
    // instead of offering actions that cannot work.
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit B1airDaemon(QObject* parent = nullptr);

    bool available() const { return m_available; }

    // ── org.b1air.Daemon ────────────────────────────────────────────────────
    Q_INVOKABLE void lock();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void volumeUp(int step = 5);
    Q_INVOKABLE void volumeDown(int step = 5);
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void brightnessUp(int step = 5);
    Q_INVOKABLE void brightnessDown(int step = 5);
    Q_INVOKABLE void brightnessSet(int value);
    Q_INVOKABLE void setGameMode(bool enabled);
    Q_INVOKABLE void capture(const QString& mode);

    // Distinct from capture(): the daemon has two independent screenshot
    // implementations (Capture wraps capture_screenshot(), this wraps the
    // richer capture() with geometry/editor support that the CLI's `capture`
    // verb uses). Keeping them separate here preserves each call site's
    // existing behavior rather than silently picking one.
    Q_INVOKABLE void captureWithGeometry(const QString& mode, const QString& geometry = QString(),
                                         bool edit = false);
    Q_INVOKABLE void power(const QString& action);

    // Reply arrives on statsReady(); `tag` is echoed back so a caller with
    // several queries in flight can tell them apart.
    Q_INVOKABLE void requestStats(const QString& query, const QString& tag = QString());

    // Remote desktop / sidecar
    Q_INVOKABLE void requestRemoteStatus(const QString& tag = QString());  // -> remoteStatusReady
    Q_INVOKABLE void remoteStop();
    Q_INVOKABLE void remotePromptFree(bool enabled);
    Q_INVOKABLE void sidecarCreate(int width = 1920, int height = 1080);
    Q_INVOKABLE void sidecarRemove();

    // Dotfiles & maintenance
    Q_INVOKABLE void dotfilesSys();
    Q_INVOKABLE void dotfilesSync();
    Q_INVOKABLE void sweeperClean();

    // Zones, mic, power profile
    Q_INVOKABLE void zonesApply(int zoneId);
    Q_INVOKABLE void micRnnoiseToggle();
    Q_INVOKABLE void powerProfileSet(const QString& name);

    // Monitors & DDC
    Q_INVOKABLE void monitorsApply(const QString& layoutJson);
    Q_INVOKABLE void ddcSet(const QString& id, int percent);

    // Equalizer
    Q_INVOKABLE void eqApply();
    Q_INVOKABLE void eqSetBand(int band, int value);
    Q_INVOKABLE void eqSetPreset(const QString& name);
    Q_INVOKABLE void eqSetAll(const QVariantList& bands);

    // Screenshot QR scan
    Q_INVOKABLE void requestScanQr(const QString& geometry, const QString& tag = QString());  // -> scanQrReady

    // ── org.b1air.Shell ─────────────────────────────────────────────────────
    Q_INVOKABLE void togglePanel(const QString& panel);
    Q_INVOKABLE void openPanel(const QString& panel, const QString& arg = QString());
    Q_INVOKABLE void closePanel(const QString& panel = QString());
    Q_INVOKABLE void forceReload();

signals:
    void availableChanged();
    void failed(const QString& method, const QString& message);
    void statsReady(const QString& tag, const QString& json);
    void remoteStatusReady(const QString& tag, const QString& json);
    void scanQrReady(const QString& tag, const QString& text);

    // Relayed from the daemon.
    void volumeChanged(int value, bool muted);
    void brightnessChanged(int value);
    void wallpaperChanged(const QString& path);
    void panelStateChanged(const QString& panel, bool open);

private slots:
    void onNameOwnerChanged(const QString& name, const QString& oldOwner, const QString& newOwner);

private:
    // Fire-and-report: dispatches asynchronously and turns a D-Bus error into
    // failed(), rather than dropping it the way execDetached did.
    void call(const QString& service, const QString& path, const QString& iface,
              const QString& method, const QVariantList& args = {});

    void refreshAvailability();

    QDBusConnection m_bus;
    bool m_available = false;
};
