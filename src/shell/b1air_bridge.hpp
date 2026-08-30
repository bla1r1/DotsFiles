#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <memory>
#include "system_control.hpp"
#include "sway_ipc.hpp"
#include "user_manager.hpp"
#include "focustime_db.hpp"
#include "settings_manager.hpp"

using namespace b1air;

// =============================================================================
// b1air Desktop Environment — Native C++ to QML Bridge
// Direct memory-speed properties and invocations without shell fork overhead.
// =============================================================================

class B1AirBridge : public QObject {
    Q_OBJECT

    // Core Properties directly mapped to memory
    Q_PROPERTY(QVariantList openWindows READ openWindows NOTIFY openWindowsChanged)
    Q_PROPERTY(QVariantList installedApps READ installedApps NOTIFY installedAppsChanged)
    Q_PROPERTY(QVariantList minimizedWindows READ minimizedWindows NOTIFY minimizedWindowsChanged)
    Q_PROPERTY(bool caffeineActive READ caffeineActive WRITE setCaffeineActive NOTIFY caffeineActiveChanged)
    Q_PROPERTY(QString powerProfile READ powerProfile WRITE setPowerProfile NOTIFY powerProfileChanged)
    Q_PROPERTY(bool dndActive READ dndActive WRITE setDndActive NOTIFY dndActiveChanged)
    Q_PROPERTY(bool gameModeActive READ gameModeActive WRITE setGameModeActive NOTIFY gameModeActiveChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ isMuted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(int micVolume READ micVolume WRITE setMicVolume NOTIFY micVolumeChanged)
    Q_PROPERTY(bool micMuted READ isMicMuted WRITE setMicMuted NOTIFY micMutedChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryPercentChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY batteryChargingChanged)
    Q_PROPERTY(bool hasBattery READ hasBattery NOTIFY batteryChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiChanged)
    Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY wifiChanged)

public:
    explicit B1AirBridge(QObject* parent = nullptr);
    virtual ~B1AirBridge() = default;

    // Getters
    QVariantList openWindows();
    QVariantList installedApps();
    QVariantList minimizedWindows();
    bool caffeineActive() const;
    QString powerProfile() const;
    bool dndActive() const;
    bool gameModeActive() const;
    int volume() const;
    bool isMuted() const;
    int micVolume() const;
    bool isMicMuted() const;
    int batteryPercent() const;
    bool batteryCharging() const;
    bool hasBattery() const;
    QString wifiSsid() const;
    bool wifiConnected() const;

    // Setters
    void setCaffeineActive(bool active);
    void setPowerProfile(const QString& profile);
    void setDndActive(bool active);
    void setGameModeActive(bool active);
    void setVolume(int vol);
    void setMuted(bool mute);
    void setMicVolume(int vol);
    void setMicMuted(bool mute);

    // QML Invocable Methods (0ms execution, in-process)
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE void focusWindow(qint64 con_id);
    Q_INVOKABLE void minimizeWindow(qint64 con_id);
    Q_INVOKABLE void restoreWindow(qint64 con_id = -1);
    Q_INVOKABLE void pickColor();
    Q_INVOKABLE void captureScreen(const QString& mode);
    Q_INVOKABLE void powerAction(const QString& action);
    Q_INVOKABLE void playSound(const QString& soundName);
    Q_INVOKABLE void refreshApps();
    Q_INVOKABLE void refreshWindows();

    // Setting store
    Q_INVOKABLE QVariant getSetting(const QString& key, const QVariant& defaultVal = QVariant());
    Q_INVOKABLE void setSetting(const QString& key, const QVariant& value);

signals:
    void openWindowsChanged();
    void installedAppsChanged();
    void minimizedWindowsChanged();
    void caffeineActiveChanged();
    void powerProfileChanged();
    void dndActiveChanged();
    void gameModeActiveChanged();
    void volumeChanged();
    void mutedChanged();
    void micVolumeChanged();
    void micMutedChanged();
    void batteryPercentChanged();
    void batteryChargingChanged();
    void batteryChanged();
    void wifiChanged();

    // IPC Command Signal dispatched to QML Root
    void ipcTriggered(const QString& action, const QString& target, const QString& argument);

private:
    void updateHardwareState();

    QTimer* m_refreshTimer;
    QVariantList m_cachedApps;
    bool m_appsLoaded = false;
    int m_volume = 50;
    bool m_muted = false;
    int m_micVolume = 50;
    bool m_micMuted = false;
    int m_batteryPercent = 100;
    bool m_batteryCharging = false;
    bool m_hasBattery = false;
    QString m_wifiSsid;
    bool m_wifiConnected = false;
    bool m_dnd = false;
    bool m_gameMode = false;
};
