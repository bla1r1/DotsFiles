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

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient)
find_package(LayerShellQt REQUIRED)
find_package(Threads REQUIRED)

set(SOURCES
    main.cpp
    b1air_bridge.cpp
    ../sway_ipc.cpp
    ../system_control.cpp
    ../user_manager.cpp
    ../focustime_db.cpp
    ../settings_manager.cpp
    ../session_manager.cpp
)

add_executable(b1air-shell ${SOURCES})

target_include_directories(b1air-shell PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(b1air-shell PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    LayerShellQt::Interface
    Threads::Threads
    sqlite3
)

install(TARGETS b1air-shell DESTINATION /usr/local/bin)
