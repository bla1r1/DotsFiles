CXX ?= ccache g++
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread -Idaemon
LDFLAGS = -lsqlite3 -lsystemd

TARGET_DAEMON = b1air-daemon
TARGET_SHELL = shell/build/b1air-shell
PREFIX ?= $(HOME)/.local/bin

DAEMON_SRCS = daemon/main.cpp daemon/daemon_dbus.cpp daemon/sway_ipc.cpp daemon/focustime_db.cpp daemon/user_manager.cpp daemon/system_control.cpp daemon/settings_manager.cpp daemon/session_manager.cpp
DAEMON_OBJS = $(DAEMON_SRCS:.cpp=.o)

all: daemon-target shell-target

daemon-target: $(TARGET_DAEMON)

$(TARGET_DAEMON): $(DAEMON_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

daemon/%.o: daemon/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

shell-target:
	cmake -B shell/build shell
	cmake --build shell/build -j$$(nproc 2>/dev/null || echo 4)

daemon: daemon-target
apps: shell-target
shell: shell-target

install: daemon-target shell-target
	mkdir -p $(PREFIX)
	install -m 755 $(TARGET_DAEMON) $(PREFIX)/$(TARGET_DAEMON)
	install -m 755 $(TARGET_SHELL) $(PREFIX)/b1air-shell
	install -m 755 shell/build/b1air-files $(PREFIX)/b1air-files 2>/dev/null || install -m 755 ../tools/b1air-files $(PREFIX)/b1air-files
	install -m 755 shell/build/b1air-settings $(PREFIX)/b1air-settings 2>/dev/null || install -m 755 ../tools/b1air-settings $(PREFIX)/b1air-settings
	install -m 755 shell/build/b1air-monitor $(PREFIX)/b1air-monitor 2>/dev/null || install -m 755 ../tools/b1air-monitor $(PREFIX)/b1air-monitor
	install -m 755 shell/build/b1air-text $(PREFIX)/b1air-text 2>/dev/null || install -m 755 ../tools/b1air-text $(PREFIX)/b1air-text
	install -m 755 shell/build/b1air-term $(PREFIX)/b1air-term 2>/dev/null || install -m 755 ../tools/b1air-term $(PREFIX)/b1air-term
	mkdir -p $(HOME)/.config/b1air-shell
	rsync -a shell/qml/ $(HOME)/.config/b1air-shell/

clean:
	rm -f $(DAEMON_OBJS) $(TARGET_DAEMON)
	rm -rf shell/build

.PHONY: all daemon-target shell-target daemon apps shell install clean
