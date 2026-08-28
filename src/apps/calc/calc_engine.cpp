#include "calc_engine.hpp"
#include <QRegularExpression>
#include <QJSEngine>
#include <QJSValue>
#include <sstream>
#include <iomanip>
#include <bitset>

CalcEngine::CalcEngine(QObject* parent) : QObject(parent) {}

QString CalcEngine::formatResult(double val) {
    if (std::isnan(val)) return "NaN";
    if (std::isinf(val)) return val > 0 ? "Infinity" : "-Infinity";

    // If integer, format with no decimals
    if (std::floor(val) == val && std::abs(val) < 1e14) {
        return QString::number(static_cast<qint64>(val));
    }
    
    // Clean precision
    QString str = QString::number(val, 'f', 6);
    while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
        bool wasDot = str.endsWith('.');
        str.chop(1);
        if (wasDot) break;
    }
    return str;
}

QVariantList CalcEngine::evaluateDocument(const QString& documentText) {
    QVariantList results;
    QStringList lines = documentText.split("\n");
    std::map<std::string, double> vars;
    vars["pi"] = 3.141592653589793;
    vars["e"] = 2.718281828459045;
    vars["tau"] = 6.283185307179586;

    double runningTotal = 0.0;
    double lastVal = 0.0;

    QJSEngine jsEngine;

    for (int i = 0; i < lines.size(); ++i) {
        QString line = lines[i].trimmed();
        QVariantMap row;
        row["lineIndex"] = i;
        row["text"] = lines[i];

        if (line.isEmpty() || line.startsWith("#") || line.startsWith("//")) {
            row["result"] = "";
            row["hasResult"] = false;
            row["isComment"] = true;
            results.append(row);
            continue;
        }

        // Special commands: total, sum, avg
        if (line.compare("total", Qt::CaseInsensitive) == 0 || line.compare("sum", Qt::CaseInsensitive) == 0) {
            row["result"] = formatResult(runningTotal);
            row["hasResult"] = true;
            row["isTotal"] = true;
            results.append(row);
            continue;
        }

        // Variable assignment: e.g. "salary = 5000"
        QString varName = "";
        QString expr = line;
        int eqIdx = line.indexOf('=');
        if (eqIdx > 0 && !line.mid(eqIdx-1, 2).contains(QRegularExpression("[!><=]="))) {
            QString potentialVar = line.left(eqIdx).trimmed();
            if (potentialVar.contains(QRegularExpression("^[a-zA-Z_][a-zA-Z0-9_]*$"))) {
                varName = potentialVar;
                expr = line.mid(eqIdx + 1).trimmed();
            }
        }

        // Standalone percentage assignment: e.g. "tax = 18%" -> "0.18"
        if (expr.endsWith("%") && expr.left(expr.size()-1).trimmed().toDouble() != 0.0) {
            double p = expr.left(expr.size()-1).trimmed().toDouble() / 100.0;
            expr = QString::number(p);
        }

        // Percentage handling: "20% of 500" -> "500 * 0.20"
        QRegularExpression pctOfRe("([0-9.]+)\\s*%\\s+of\\s+([0-9.]+)");
        auto match = pctOfRe.match(expr);
        if (match.hasMatch()) {
            double p = match.captured(1).toDouble() / 100.0;
            double base = match.captured(2).toDouble();
            expr.replace(match.captured(0), QString::number(p * base));
        }

        // Percentage addition/subtraction: "150 + 20%" -> "150 * 1.20" or "(...) - 18%"
        QRegularExpression pctAddRe("([0-9.]+)\\s*([+\\-])\\s*([0-9.]+)\\s*%");
        match = pctAddRe.match(expr);
        if (match.hasMatch()) {
            double base = match.captured(1).toDouble();
            QString sign = match.captured(2);
            double pct = match.captured(3).toDouble() / 100.0;
            double val = (sign == "+") ? base * (1.0 + pct) : base * (1.0 - pct);
            expr.replace(match.captured(0), QString::number(val));
        }

        // Unit conversion shorthands
        // Bytes: MB in GB, GB in TB
        if (expr.contains(" in gb", Qt::CaseInsensitive)) {
            expr.replace(QRegularExpression("([0-9.]+)\\s*mb\\s+in\\s+gb", QRegularExpression::CaseInsensitiveOption), "(\\1 / 1024)");
        } else if (expr.contains(" in tb", Qt::CaseInsensitive)) {
            expr.replace(QRegularExpression("([0-9.]+)\\s*gb\\s+in\\s+tb", QRegularExpression::CaseInsensitiveOption), "(\\1 / 1024)");
        } else if (expr.contains(" in mb", Qt::CaseInsensitive)) {
            expr.replace(QRegularExpression("([0-9.]+)\\s*kb\\s+in\\s+mb", QRegularExpression::CaseInsensitiveOption), "(\\1 / 1024)");
            expr.replace(QRegularExpression("([0-9.]+)\\s*gb\\s+in\\s+mb", QRegularExpression::CaseInsensitiveOption), "(\\1 * 1024)");
        }

        // Length: km in miles, miles in km
        if (expr.contains(" in miles", Qt::CaseInsensitive)) {
            expr.replace(QRegularExpression("([0-9.]+)\\s*km\\s+in\\s+miles", QRegularExpression::CaseInsensitiveOption), "(\\1 * 0.621371)");
        } else if (expr.contains(" in km", Qt::CaseInsensitive)) {
            expr.replace(QRegularExpression("([0-9.]+)\\s*miles\\s+in\\s+km", QRegularExpression::CaseInsensitiveOption), "(\\1 * 1.60934)");
        }

        // Exponentiation ^ -> **
        expr.replace("^", "**");

        // Inject known variables into JS context
        for (const auto& [k, v] : vars) {
            jsEngine.globalObject().setProperty(QString::fromStdString(k), v);
        }
        jsEngine.globalObject().setProperty("prev", lastVal);
        jsEngine.globalObject().setProperty("ans", lastVal);

        QJSValue jsRes = jsEngine.evaluate(expr);
        if (!jsRes.isError() && jsRes.isNumber()) {
            double val = jsRes.toNumber();
            lastVal = val;
            runningTotal += val;

            if (!varName.isEmpty()) {
                vars[varName.toStdString()] = val;
                row["varName"] = varName;
            }

            row["result"] = formatResult(val);
            row["numericValue"] = val;
            row["hasResult"] = true;
            row["isError"] = false;
        } else {
            row["result"] = "";
            row["hasResult"] = false;
            row["isError"] = true;
        }

        results.append(row);
    }

    return results;
}

QVariantMap CalcEngine::evaluateLine(const QString& line, const QVariantMap& contextVars) {
    QVariantMap res;
    QJSEngine js;
    for (auto it = contextVars.begin(); it != contextVars.end(); ++it) {
        js.globalObject().setProperty(it.key(), it.value().toDouble());
    }
    QJSValue val = js.evaluate(line);
    if (!val.isError() && val.isNumber()) {
        res["result"] = formatResult(val.toNumber());
        res["numericValue"] = val.toNumber();
        res["ok"] = true;
    } else {
        res["ok"] = false;
        res["error"] = val.toString();
    }
    return res;
}

QVariantMap CalcEngine::convertBase(const QString& input, int fromBase) {
    QVariantMap map;
    QString clean = input.trimmed();
    clean.remove(" ");
    clean.remove("_");

    bool ok = false;
    uint64_t val = 0;

    if (clean.startsWith("0x", Qt::CaseInsensitive)) {
        val = clean.toULongLong(&ok, 16);
    } else if (clean.startsWith("0b", Qt::CaseInsensitive)) {
        val = clean.mid(2).toULongLong(&ok, 2);
    } else if (clean.startsWith("0o", Qt::CaseInsensitive)) {
        val = clean.mid(2).toULongLong(&ok, 8);
    } else {
        val = clean.toULongLong(&ok, fromBase);
    }

    if (!ok) {
        map["ok"] = false;
        return map;
    }

    map["ok"] = true;
    map["val"] = static_cast<qint64>(val);
    
    // Hex
    std::stringstream ssHex;
    ssHex << "0x" << std::uppercase << std::hex << val;
    map["hex"] = QString::fromStdString(ssHex.str());

    // Dec
    map["dec"] = QString::number(val);

    // Oct
    std::stringstream ssOct;
    ssOct << "0o" << std::oct << val;
    map["oct"] = QString::fromStdString(ssOct.str());

    // Bin (grouped in 4-bit nibbles)
    std::string binStr = std::bitset<64>(val).to_string();
    size_t firstOne = binStr.find('1');
    if (firstOne == std::string::npos) firstOne = 60; // show at least 4 bits
    firstOne = (firstOne / 4) * 4; // round down to nibble boundary
    std::string trimmedBin = binStr.substr(firstOne);

    QString groupedBin = "0b ";
    for (size_t i = 0; i < trimmedBin.size(); ++i) {
        if (i > 0 && i % 4 == 0) groupedBin += " ";
        groupedBin += trimmedBin[i];
    }
    map["bin"] = groupedBin;

    // Fixed width representations
    map["uint8"] = static_cast<quint8>(val);
    map["uint16"] = static_cast<quint16>(val);
    map["uint32"] = static_cast<quint32>(val);
    map["int32"] = static_cast<qint32>(val);
    map["int64"] = static_cast<qint64>(val);

    // ASCII preview (printable chars)
    QString asciiStr = "";
    for (int i = 7; i >= 0; --i) {
        char c = (val >> (i * 8)) & 0xFF;
        if (c >= 32 && c <= 126) asciiStr += c;
        else if (c != 0) asciiStr += ".";
    }
    map["ascii"] = asciiStr.trimmed();

    return map;
}

qint64 CalcEngine::bitwiseOp(const QString& op, qint64 a, qint64 b) {
    if (op == "AND" || op == "&") return a & b;
    if (op == "OR"  || op == "|") return a | b;
    if (op == "XOR" || op == "^") return a ^ b;
    if (op == "NOT" || op == "~") return ~a;
    if (op == "LSHIFT" || op == "<<") return a << b;
    if (op == "RSHIFT" || op == ">>") return a >> b;
    return a;
}

QString CalcEngine::toBase64(const QString& input) {
    return QString::fromUtf8(input.toUtf8().toBase64());
}

QString CalcEngine::fromBase64(const QString& input) {
    return QString::fromUtf8(QByteArray::fromBase64(input.toUtf8()));
}

QString CalcEngine::formatTimestamp(qint64 epoch) {
    QDateTime dt = QDateTime::fromSecsSinceEpoch(epoch);
    return dt.toString("yyyy-MM-dd HH:mm:ss t");
}

qint64 CalcEngine::currentTimestamp() {
    return QDateTime::currentSecsSinceEpoch();
}
