#include "focustime_db.hpp"
#include <sys/stat.h>
#include <unistd.h>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <ctime>
#include <iomanip>
#include <algorithm>

namespace b1air {

FocusTimeDB::FocusTimeDB() {
    db_path_ = default_db_path();
}

FocusTimeDB::~FocusTimeDB() {
    close();
}

std::string FocusTimeDB::default_db_path() {
    const char* home = std::getenv("HOME");
    std::string base = home ? home : "/tmp";
    std::string dir = base + "/.local/share/focustime";
    mkdir(dir.c_str(), 0755);
    return dir + "/focustime.db";
}

bool FocusTimeDB::open(const std::string& custom_path) {
    if (!custom_path.empty()) {
        db_path_ = custom_path;
    }
    if (sqlite3_open(db_path_.c_str(), &db_) != SQLITE_OK) {
        return false;
    }
    return init_schema();
}

void FocusTimeDB::close() {
    if (db_) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

bool FocusTimeDB::init_schema() {
    if (!db_) return false;

    const char* schema = 
        "CREATE TABLE IF NOT EXISTS events ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  start_time INTEGER NOT NULL,"
        "  end_time INTEGER NOT NULL,"
        "  app_class TEXT NOT NULL,"
        "  window_title TEXT,"
        "  duration INTEGER NOT NULL,"
        "  is_locked INTEGER DEFAULT 0"
        ");"
        "CREATE INDEX IF NOT EXISTS idx_events_time ON events(start_time, end_time);"
        "CREATE INDEX IF NOT EXISTS idx_events_app ON events(app_class);";

    char* err = nullptr;
    if (sqlite3_exec(db_, schema, nullptr, nullptr, &err) != SQLITE_OK) {
        if (err) {
            sqlite3_free(err);
        }
        return false;
    }
    return true;
}

bool FocusTimeDB::log_interval(int64_t start_ts, int64_t end_ts, const std::string& app_class, const std::string& title, bool is_locked) {
    if (!db_ || end_ts <= start_ts) return false;
    int64_t dur = end_ts - start_ts;

    const char* sql = "INSERT INTO events (start_time, end_time, app_class, window_title, duration, is_locked) VALUES (?, ?, ?, ?, ?, ?);";
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        return false;
    }

    sqlite3_bind_int64(stmt, 1, start_ts);
    sqlite3_bind_int64(stmt, 2, end_ts);
    sqlite3_bind_text(stmt, 3, app_class.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, title.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 5, dur);
    sqlite3_bind_int(stmt, 6, is_locked ? 1 : 0);

    bool ok = (sqlite3_step(stmt) == SQLITE_DONE);
    sqlite3_finalize(stmt);
    return ok;
}

static std::pair<int64_t, int64_t> get_day_range(const std::string& date_str) {
    // Format "YYYY-MM-DD"
    struct tm tm_start = {};
    if (date_str.size() == 10 && strptime(date_str.c_str(), "%Y-%m-%d", &tm_start)) {
        tm_start.tm_hour = 0;
        tm_start.tm_min = 0;
        tm_start.tm_sec = 0;
        time_t start_ts = mktime(&tm_start);
        return { static_cast<int64_t>(start_ts), static_cast<int64_t>(start_ts + 86400) };
    }

    // Default today
    time_t now = time(nullptr);
    struct tm* l = localtime(&now);
    l->tm_hour = 0;
    l->tm_min = 0;
    l->tm_sec = 0;
    time_t today_start = mktime(l);
    return { static_cast<int64_t>(today_start), static_cast<int64_t>(today_start + 86400) };
}

DayStats FocusTimeDB::get_stats_for_date(const std::string& date_str) {
    DayStats stats;
    stats.date = date_str;
    if (!db_) return stats;

    auto [start_ts, end_ts] = get_day_range(date_str);

    // Sum active apps
    const char* app_sql = 
        "SELECT app_class, SUM(duration) as total_dur, COUNT(*) as cnt "
        "FROM events "
        "WHERE start_time >= ? AND start_time < ? AND is_locked = 0 AND app_class != 'Screen Locked' "
        "GROUP BY app_class "
        "ORDER BY total_dur DESC;";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, app_sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, start_ts);
        sqlite3_bind_int64(stmt, 2, end_ts);

        while (sqlite3_step(stmt) == SQLITE_ROW) {
            AppStat app;
            const unsigned char* cls = sqlite3_column_text(stmt, 0);
            app.app_class = cls ? reinterpret_cast<const char*>(cls) : "unknown";
            app.display_name = app.app_class;
            app.total_seconds = sqlite3_column_int64(stmt, 1);
            app.count = sqlite3_column_int(stmt, 2);
            stats.total_active_seconds += app.total_seconds;
            stats.apps.push_back(app);
        }
        sqlite3_finalize(stmt);
    }

    // Sum locked time
    const char* lock_sql = 
        "SELECT SUM(duration) FROM events WHERE start_time >= ? AND start_time < ? AND (is_locked = 1 OR app_class = 'Screen Locked');";
    if (sqlite3_prepare_v2(db_, lock_sql, -1, &stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, start_ts);
        sqlite3_bind_int64(stmt, 2, end_ts);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            stats.total_locked_seconds = sqlite3_column_int64(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }

    return stats;
}

static std::string escape_json(const std::string& s) {
    std::ostringstream o;
    for (char c : s) {
        if (c == '"') o << "\\\"";
        else if (c == '\\') o << "\\\\";
        else if (c == '\b') o << "\\b";
        else if (c == '\f') o << "\\f";
        else if (c == '\n') o << "\\n";
        else if (c == '\r') o << "\\r";
        else if (c == '\t') o << "\\t";
        else o << c;
    }
    return o.str();
}

std::string FocusTimeDB::get_stats_json(const std::string& date_str) {
    DayStats stats = get_stats_for_date(date_str);

    std::ostringstream ss;
    ss << "{\n";
    ss << "  \"date\": \"" << escape_json(stats.date) << "\",\n";
    ss << "  \"total_active_seconds\": " << stats.total_active_seconds << ",\n";
    ss << "  \"total_locked_seconds\": " << stats.total_locked_seconds << ",\n";
    ss << "  \"apps\": [\n";

    for (size_t i = 0; i < stats.apps.size(); ++i) {
        const auto& a = stats.apps[i];
        ss << "    {\n";
        ss << "      \"app_class\": \"" << escape_json(a.app_class) << "\",\n";
        ss << "      \"display_name\": \"" << escape_json(a.display_name) << "\",\n";
        ss << "      \"total_seconds\": " << a.total_seconds << ",\n";
        ss << "      \"count\": " << a.count << "\n";
        ss << "    }" << (i + 1 < stats.apps.size() ? "," : "") << "\n";
    }

    ss << "  ]\n";
    ss << "}\n";
    return ss.str();
}

} // namespace b1air
