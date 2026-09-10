#include "qs_services.hpp"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QVariant>

namespace qscompat {

// ── UPowerDevice ─────────────────────────────────────────────────────────────

void UPowerDevice::setFrom(const QVariantMap& props) {
    // UPower's Type enumeration: 2 is Battery.
    m_laptop = props.value("Type").toUInt() == 2;
    m_present = props.value("IsPresent").toBool();
    m_rechargeable = props.value("IsRechargeable").toBool();
    // Quickshell normalises this to 0..1 and the shell's arithmetic follows it;
    // UPower's own Percentage is 0..100.
    m_percentage = props.value("Percentage").toDouble() / 100.0;
    // Capacity is already 0..100 in UPower, and healthPercentage is not
    // normalised in Quickshell either.
    m_health = props.value("Capacity").toDouble();
    m_state = props.value("State").toInt();
    m_model = props.value("Model").toString();
    m_nativePath = props.value("NativePath").toString();
    m_toEmpty = props.value("TimeToEmpty").toDouble();
    m_toFull = props.value("TimeToFull").toDouble();
    emit changed();
}

// ── UPower ───────────────────────────────────────────────────────────────────

static QVariantMap dbusProperties(const QString& service, const QString& path,
                                  const QString& iface) {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        service, path, "org.freedesktop.DBus.Properties", "GetAll");
    msg << iface;
    const QDBusMessage reply = QDBusConnection::systemBus().call(msg, QDBus::Block, 1500);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return {};

    QVariantMap out;
    const QDBusArgument arg = reply.arguments().first().value<QDBusArgument>();
    arg.beginMap();
    while (!arg.atEnd()) {
        QString key;
        QVariant value;
        arg.beginMapEntry();
        arg >> key >> value;
        arg.endMapEntry();
        out.insert(key, value);
    }
    arg.endMap();
    return out;
}

UPower::UPower(QObject* parent)
    : QObject(parent), m_devices(new ObjectList(this)), m_display(new UPowerDevice(this)) {
    refresh();
    // The settings window is short-lived and open in front of someone; a poll
    // every few seconds is honest here in a way it would not be in a shell that
    // runs all day.
    auto* t = new QTimer(this);
    t->setInterval(5000);
    connect(t, &QTimer::timeout, this, &UPower::refresh);
    t->start();
}

void UPower::refresh() {
    const QString service = "org.freedesktop.UPower";

    m_display->setFrom(dbusProperties(service, "/org/freedesktop/UPower/devices/DisplayDevice",
                                      "org.freedesktop.UPower.Device"));

    QDBusInterface up(service, "/org/freedesktop/UPower", "org.freedesktop.UPower",
                      QDBusConnection::systemBus());
    const QDBusReply<QList<QDBusObjectPath>> reply = up.call("EnumerateDevices");

    QVariantList values;
    if (reply.isValid()) {
        for (const QDBusObjectPath& p : reply.value()) {
            const QVariantMap props =
                dbusProperties(service, p.path(), "org.freedesktop.UPower.Device");
            if (props.isEmpty())
                continue;
            auto* dev = new UPowerDevice(this);
            dev->setFrom(props);
            values.append(QVariant::fromValue(static_cast<QObject*>(dev)));
        }
    }
    m_devices->setValues(values);
    emit changed();
}

// ── PipeWire, through wpctl ──────────────────────────────────────────────────

void PwAudio::setVolume(qreal v) {
    m_volume = v;
    emit changed();
    if (!m_node.isEmpty())
        QProcess::startDetached("wpctl", {"set-volume", m_node, QString::number(v, 'f', 2)});
}

void PwAudio::setMuted(bool m) {
    m_muted = m;
    emit changed();
    if (!m_node.isEmpty())
        QProcess::startDetached("wpctl", {"set-mute", m_node, m ? "1" : "0"});
}

void PwNode::init(int id, const QString& name, const QString& description,
                  bool isSink, bool isStream, qreal volume, bool muted) {
    m_id = id;
    m_name = name;
    m_description = description;
    m_isSink = isSink;
    m_isStream = isStream;
    m_audio->setNodeName(QString::number(id));
    m_audio->apply(volume, muted);
}

Pipewire::Pipewire(QObject* parent) : QObject(parent), m_nodes(new ObjectList(this)) {
    refresh();
    auto* t = new QTimer(this);
    t->setInterval(5000);
    connect(t, &QTimer::timeout, this, &Pipewire::refresh);
    t->start();
}

void Pipewire::refresh() {
    // `wpctl status` rather than a PipeWire client: this desktop already
    // depends on wireplumber, and a settings window does not need the live
    // graph that the shell gets from a real connection.
    QProcess p;
    p.start("wpctl", {"status"});
    if (!p.waitForFinished(2000))
        return;
    const QString out = QString::fromUtf8(p.readAllStandardOutput());

    QVariantList values;
    PwNode* sink = nullptr;
    PwNode* source = nullptr;

    // Lines look like:  │  *   49. Built-in Audio Analogue Stereo [vol: 0.65]
    static const QRegularExpression re(
        R"(^\s*[│├└─\s]*(\*?)\s*(\d+)\.\s+(.*?)(?:\s+\[vol:\s*([0-9.]+)(\s+MUTED)?\])?\s*$)");

    bool inSinks = false, inSources = false;
    for (const QString& raw : out.split('\n')) {
        if (raw.contains("Sinks:"))        { inSinks = true;  inSources = false; continue; }
        if (raw.contains("Sources:"))      { inSinks = false; inSources = true;  continue; }
        if (raw.contains("Filters:") || raw.contains("Streams:") || raw.contains("Video"))
                                           { inSinks = false; inSources = false; continue; }
        if (!inSinks && !inSources)
            continue;

        const auto m = re.match(raw);
        if (!m.hasMatch())
            continue;

        const bool isDefault = m.captured(1) == "*";
        const int id = m.captured(2).toInt();
        const QString name = m.captured(3).trimmed();
        if (name.isEmpty())
            continue;
        const qreal vol = m.captured(4).isEmpty() ? 0.0 : m.captured(4).toDouble();
        const bool muted = !m.captured(5).isEmpty();

        auto* node = new PwNode(this);
        node->init(id, name, name, inSinks, false, vol, muted);
        values.append(QVariant::fromValue(static_cast<QObject*>(node)));

        if (isDefault && inSinks)   sink = node;
        if (isDefault && inSources) source = node;
    }

    m_nodes->setValues(values);
    m_sink = sink;
    m_source = source;
    emit changed();
}

// ── Registration ─────────────────────────────────────────────────────────────

void registerServiceTypes() {
    qmlRegisterUncreatableType<UPowerDevice>("Quickshell.Services.UPower", 1, 0,
                                             "UPowerDevice", "read-only");
    qmlRegisterUncreatableType<ObjectList>("Quickshell.Services.UPower", 1, 0,
                                           "ObjectList", "read-only");
    qmlRegisterSingletonType<UPower>(
        "Quickshell.Services.UPower", 1, 0, "UPower",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new UPower(); });

    // The state enumeration the shell switches on, with UPower's own numbering.
    qmlRegisterSingletonType("Quickshell.Services.UPower", 1, 0, "UPowerDeviceState",
                             [](QQmlEngine* e, QJSEngine*) -> QJSValue {
        QJSValue o = e->newObject();
        o.setProperty("Unknown", 0);
        o.setProperty("Charging", 1);
        o.setProperty("Discharging", 2);
        o.setProperty("Empty", 3);
        o.setProperty("FullyCharged", 4);
        o.setProperty("PendingCharge", 5);
        o.setProperty("PendingDischarge", 6);
        return o;
    });

    qmlRegisterUncreatableType<PwNode>("Quickshell.Services.Pipewire", 1, 0, "PwNode", "read-only");
    qmlRegisterUncreatableType<PwAudio>("Quickshell.Services.Pipewire", 1, 0, "PwAudio", "read-only");
    qmlRegisterType<PwObjectTracker>("Quickshell.Services.Pipewire", 1, 0, "PwObjectTracker");
    qmlRegisterSingletonType<Pipewire>(
        "Quickshell.Services.Pipewire", 1, 0, "Pipewire",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new Pipewire(); });

    qmlRegisterSingletonType<Bluetooth>(
        "Quickshell.Bluetooth", 1, 0, "Bluetooth",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new Bluetooth(); });

    qmlRegisterSingletonType<Networking>(
        "Quickshell.Networking", 1, 0, "Networking",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new Networking(); });

    qmlRegisterSingletonType<Mpris>(
        "Quickshell.Services.Mpris", 1, 0, "Mpris",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new Mpris(); });

    qmlRegisterType<NotificationServer>("Quickshell.Services.Notifications", 1, 0,
                                        "NotificationServer");
}

} // namespace qscompat
