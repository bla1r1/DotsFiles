#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <cmath>
#include <cstdint>
#include <string>
#include <map>

class CalcEngine : public QObject {
    Q_OBJECT

public:
    explicit CalcEngine(QObject* parent = nullptr);

    // Multi-line scratchpad evaluation
    Q_INVOKABLE QVariantList evaluateDocument(const QString& documentText);
    Q_INVOKABLE QVariantMap evaluateLine(const QString& line, const QVariantMap& contextVars);

    // Programmer radix conversions
    Q_INVOKABLE QVariantMap convertBase(const QString& input, int fromBase = 10);
    Q_INVOKABLE qint64 bitwiseOp(const QString& op, qint64 a, qint64 b);

    // Encoders & Utilities
    Q_INVOKABLE QString toBase64(const QString& input);
    Q_INVOKABLE QString fromBase64(const QString& input);
    Q_INVOKABLE QString formatTimestamp(qint64 epoch);
    Q_INVOKABLE qint64 currentTimestamp();

private:
    double parseExpr(const QString& expr, const std::map<std::string, double>& vars, bool& ok, QString& error);
    QString formatResult(double val);
};
