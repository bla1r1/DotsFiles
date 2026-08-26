#include "b1air_bridge.hpp"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QClipboard>
#include <QGuiApplication>
#include <QProcess>
#include <iostream>

using namespace b1air;

B1AirBridge::B1AirBridge(QObject* parent) : QObject(parent) {
    m_refreshTimer = new QTimer(this);
    connect(m_refreshTimer, &QTimer::timeout, this, &B1AirBridge::updateHardwareState);
    m_refreshTimer->start(2500); // 2.5s passive telemetry sync

    // Initial load
    refreshApps();
    updateHardwareState();
}

void B1AirBridge::updateHardwareState() {
    // Volume & Audio status
    int vol = SystemControl::get_volume();
    if (vol != m_volume) {
        m_volume = vol;
        emit volumeChanged();
    }

    std::string mic_st = SystemControl::get_mic_status();
    bool mic_m = (mic_st.find("muted") != std::string::npos || mic_st == "0");
    if (mic_m != m_micMuted) {
        m_micMuted = mic_m;
        emit micMutedChanged();
    }

    // Wi-Fi status
    std::string wifi_json = SystemControl::get_wifi_status_json();
    if (!wifi_json.empty()) {
        QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(wifi_json));
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            m_wifiConnected = obj.value("connected").toBool(false);
            m_wifiSsid = obj.value("ssid").toString();
            emit wifiChanged();
        }
    }
}

QVariantList B1AirBridge::openWindows() {
    std::string json_str = SystemControl::window_list_open_json();
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(json_str));
    if (doc.isArray()) {
        return doc.array().toVariantList();
    }
    return QVariantList();
}

QVariantList B1AirBridge::installedApps() {
    if (!m_appsLoaded || m_cachedApps.isEmpty()) {
        refreshApps();
    }
    return m_cachedApps;
}

void B1AirBridge::refreshApps() {
    std::string json_str = SystemControl::apps_list_json("all");
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(json_str));
    if (doc.isArray()) {
        m_cachedApps = doc.array().toVariantList();
        m_appsLoaded = true;
        emit installedAppsChanged();
    }
}

void B1AirBridge::refreshWindows() {
    emit openWindowsChanged();
    emit minimizedWindowsChanged();
}

QVariantList B1AirBridge::minimizedWindows() {
    std::string json_str = SystemControl::window_list_minimized_json();
    QJsonDocument doc = QJsonDocument::fromJson(QByteArray::fromStdString(json_str));
    if (doc.isArray()) {
        return doc.array().toVariantList();
    }
    return QVariantList();
}

bool B1AirBridge::caffeineActive() const {
    return SystemControl::caffeine_is_active();
}

void B1AirBridge::setCaffeineActive(bool active) {
    SystemControl::caffeine_set(active);
    emit caffeineActiveChanged();
}

QString B1AirBridge::powerProfile() const {
    return QString::fromStdString(SystemControl::power_profile_get());
}

void B1AirBridge::setPowerProfile(const QString& profile) {
    SystemControl::power_profile_set(profile.toStdString());
    emit powerProfileChanged();
}

bool B1AirBridge::dndActive() const {
    return m_dnd;
}

void B1AirBridge::setDndActive(bool active) {
    m_dnd = active;
    emit dndActiveChanged();
}

bool B1AirBridge::gameModeActive() const {
    return m_gameMode;
}

void B1AirBridge::setGameModeActive(bool active) {
    m_gameMode = active;
    if (active) {
        SystemControl::enable_game_mode();
    } else {
        SystemControl::disable_game_mode();
    }
    emit gameModeActiveChanged();
}

int B1AirBridge::volume() const { return m_volume; }
bool B1AirBridge::isMuted() const { return m_muted; }
int B1AirBridge::micVolume() const { return m_micVolume; }
bool B1AirBridge::isMicMuted() const { return m_micMuted; }
int B1AirBridge::batteryPercent() const { return m_batteryPercent; }
bool B1AirBridge::batteryCharging() const { return m_batteryCharging; }
bool B1AirBridge::hasBattery() const { return m_hasBattery; }
QString B1AirBridge::wifiSsid() const { return m_wifiSsid; }
bool B1AirBridge::wifiConnected() const { return m_wifiConnected; }

void B1AirBridge::setVolume(int vol) {
    m_volume = vol;
    std::string cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + std::to_string(vol) + "% 2>/dev/null";
    std::system(cmd.c_str());
    emit volumeChanged();
}

void B1AirBridge::setMuted(bool mute) {
    m_muted = mute;
    SystemControl::volume_toggle_mute();
    emit mutedChanged();
}

void B1AirBridge::setMicVolume(int vol) {
    m_micVolume = vol;
    std::string cmd = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + std::to_string(vol) + "% 2>/dev/null";
    std::system(cmd.c_str());
    emit micVolumeChanged();
}

void B1AirBridge::setMicMuted(bool mute) {
    m_micMuted = mute;
    SystemControl::mic_toggle();
    emit micMutedChanged();
}

void B1AirBridge::execute(const QString& command) {
    QProcess::startDetached("bash", QStringList() << "-c" << command);
}

void B1AirBridge::copyToClipboard(const QString& text) {
    QClipboard* cb = QGuiApplication::clipboard();
    if (cb) {
        cb->setText(text, QClipboard::Clipboard);
        cb->setText(text, QClipboard::Selection);
    }
}

void B1AirBridge::focusWindow(qint64 con_id) {
    std::string cmd = "swaymsg [con_id=" + std::to_string(con_id) + "] focus 2>/dev/null &";
    std::system(cmd.c_str());
}

void B1AirBridge::minimizeWindow(qint64 con_id) {
    if (con_id > 0) {
        std::string cmd = "swaymsg [con_id=" + std::to_string(con_id) + "] mark --add _b1air_minimized, move scratchpad 2>/dev/null &";
        std::system(cmd.c_str());
    } else {
        SystemControl::window_minimize();
    }
    emit openWindowsChanged();
    emit minimizedWindowsChanged();
}

void B1AirBridge::restoreWindow(qint64 con_id) {
    SystemControl::window_restore(con_id);
    emit openWindowsChanged();
    emit minimizedWindowsChanged();
}

void B1AirBridge::pickColor() {
    SystemControl::pick_color();
}

void B1AirBridge::captureScreen(const QString& mode) {
    SystemControl::capture(mode.toStdString());
}

void B1AirBridge::powerAction(const QString& action) {
    if (action == "lock") SystemControl::lock_session();
    else if (action == "logout") SystemControl::logout_session();
    else if (action == "suspend") SystemControl::suspend_system();
    else if (action == "reboot") SystemControl::reboot_system();
    else if (action == "shutdown" || action == "poweroff") SystemControl::shutdown_system();
}

void B1AirBridge::playSound(const QString& soundName) {
    std::string cmd = "canberra-gtk-play -i " + soundName.toStdString() + " 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/" + soundName.toStdString() + ".oga 2>/dev/null &";
    std::system(cmd.c_str());
}

QVariant B1AirBridge::getSetting(const QString& key, const QVariant& defaultVal) {
    std::string val = SettingsManager::get_json_string(key.toStdString());
    if (val.empty()) return defaultVal;
    return QString::fromStdString(val);
}

void B1AirBridge::setSetting(const QString& key, const QVariant& value) {
    SettingsManager::set_json_value(key.toStdString(), value.toString().toStdString());
}
