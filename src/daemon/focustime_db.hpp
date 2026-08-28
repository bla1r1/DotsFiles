#pragma once
#include <string>
#include <vector>
#include <cstdint>
#include <sqlite3.h>

namespace b1air {

struct AppStat {
    std::string app_class;
    std::string display_name;
    int64_t total_seconds = 0;
    int count = 0;
};

struct DayStats {
    std::string date;
    int64_t total_active_seconds = 0;
    int64_t total_locked_seconds = 0;
    std::vector<AppStat> apps;
};

class FocusTimeDB {
public:
    FocusTimeDB();
    ~FocusTimeDB();

    bool open(const std::string& custom_path = "");
    void close();

    bool log_interval(int64_t start_ts, int64_t end_ts, const std::string& app_class, const std::string& title, bool is_locked);
    DayStats get_stats_for_date(const std::string& date_str);
    std::string get_stats_json(const std::string& date_str);

private:
    sqlite3* db_ = nullptr;
    std::string db_path_;

    bool init_schema();
    std::string default_db_path();
};

} // namespace b1air
