cmake_minimum_required(VERSION 3.20)
project(b1air-shell LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CCACHE_PROGRAM}")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml QmlModels Quick WaylandClient DBus Network)
find_package(LayerShellQt REQUIRED)
find_package(Threads REQUIRED)

set(SOURCES
    main.cpp
    b1air_bridge.cpp
    dbus_adaptor.cpp
    ../daemon/daemon_dbus.cpp
    ../daemon/sway_ipc.cpp
    ../daemon/system_control.cpp
    ../daemon/user_manager.cpp
    ../daemon/focustime_db.cpp
    ../daemon/settings_manager.cpp
    ../daemon/session_manager.cpp
)

add_executable(b1air-shell ${SOURCES})

target_include_directories(b1air-shell PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_SOURCE_DIR}/../daemon
)

target_link_libraries(b1air-shell PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Qt6::DBus
    LayerShellQt::Interface
    Threads::Threads
    sqlite3
    systemd
)

# ── b1air-files (Native File Manager & Gallery) ──────────────────────────────
add_executable(b1air-files
    ../apps/files/main.cpp
    ../apps/files/backend.cpp
)

target_include_directories(b1air-files PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/files
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-files PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-monitor (Native Activity Monitor & Task Manager) ───────────────────
add_executable(b1air-monitor
    ../apps/monitor/main.cpp
    ../apps/monitor/backend.cpp
)

target_include_directories(b1air-monitor PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/monitor
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-monitor PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-text (Native Minimal Text & Config Editor) ─────────────────────────
add_executable(b1air-text
    ../apps/text/main.cpp
    ../apps/text/backend.cpp
)

target_include_directories(b1air-text PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/text
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-text PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-settings (Native Desktop Settings Application) ─────────────────────
add_executable(b1air-settings
    ../apps/settings/main.cpp
)

target_include_directories(b1air-settings PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/settings
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-settings PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-term (Native Terminal Emulator) ────────────────────────────────────
add_executable(b1air-term
    ../apps/term/main.cpp
    ../apps/term/terminal_item.cpp
)

target_include_directories(b1air-term PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/term
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-term PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
    vterm
    util
)

# ── b1air-calc (Native Smart Scratchpad & Programmer Calculator) ──────────────
add_executable(b1air-calc
    ../apps/calc/main.cpp
    ../apps/calc/calc_engine.cpp
)

target_include_directories(b1air-calc PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/calc
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-calc PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-view (Native Lightweight Image & Media Viewer) ──────────────────────
add_executable(b1air-view
    ../apps/view/main.cpp
    ../apps/view/view_backend.cpp
)

target_include_directories(b1air-view PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/view
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-view PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

# ── b1air-notes (Native Markdown Scratchpad with Obsidian & Notion Sync) ──────
add_executable(b1air-notes
    ../apps/notes/main.cpp
    ../apps/notes/notes_backend.cpp
)

target_include_directories(b1air-notes PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/notes
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-notes PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Qt6::Network
    Threads::Threads
)

# ── b1air-git (Native Visual Git & Diff Tool) ─────────────────────────────────
add_executable(b1air-git
    ../apps/git/main.cpp
    ../apps/git/git_backend.cpp
)

target_include_directories(b1air-git PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../apps/git
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-git PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Threads::Threads
)

install(TARGETS b1air-shell b1air-files b1air-monitor b1air-text b1air-settings b1air-term b1air-calc b1air-view b1air-notes b1air-git DESTINATION /usr/local/bin)
