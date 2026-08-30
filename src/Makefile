CXX ?= ccache g++
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread -Idaemon
LDFLAGS = -lsqlite3 -lsystemd -lcrypto
POLKIT_CFLAGS ?= $(shell pkg-config --cflags polkit-agent-1 2>/dev/null)
POLKIT_LIBS ?= $(shell pkg-config --libs polkit-agent-1 2>/dev/null)

TARGET_DAEMON = b1air-daemon
TARGET_SHELL = shell/build/b1air-shell
TARGET_POLKIT = b1air-polkit-agent
TARGET_SECRET = b1air-secret-service
TARGET_CONTROLLER = ../tools/controller
PREFIX ?= $(HOME)/.local/bin

DAEMON_SRCS = daemon/main.cpp daemon/daemon_dbus.cpp daemon/sway_ipc.cpp daemon/focustime_db.cpp daemon/user_manager.cpp daemon/system_control.cpp daemon/settings_manager.cpp daemon/session_manager.cpp daemon/secret_store.cpp
DAEMON_OBJS = $(DAEMON_SRCS:.cpp=.o)
POLKIT_SRCS = daemon/polkit_agent_main.cpp daemon/system_control.cpp daemon/sway_ipc.cpp daemon/focustime_db.cpp daemon/user_manager.cpp daemon/settings_manager.cpp daemon/secret_store.cpp
POLKIT_OBJS = $(POLKIT_SRCS:.cpp=.o)
SECRET_SRCS = daemon/secret_service_main.cpp daemon/secret_store.cpp
SECRET_OBJS = $(SECRET_SRCS:.cpp=.o)

all: daemon-target polkit-target secret-target shell-target controller

daemon-target: $(TARGET_DAEMON)

polkit-target: $(TARGET_POLKIT)

secret-target: $(TARGET_SECRET)

$(TARGET_DAEMON): $(DAEMON_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(TARGET_POLKIT): $(POLKIT_OBJS)
	$(CXX) $(CXXFLAGS) $(POLKIT_CFLAGS) -o $@ $^ $(LDFLAGS) $(POLKIT_LIBS)

$(TARGET_SECRET): $(SECRET_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ -lcrypto

daemon/%.o: daemon/%.cpp
	$(CXX) $(CXXFLAGS) $(if $(filter daemon/polkit_agent_main.cpp,$<),$(POLKIT_CFLAGS),) -c $< -o $@

shell-target:
	cmake -B shell/build shell
	cmake --build shell/build -j$$(nproc 2>/dev/null || echo 4)

controller: $(TARGET_CONTROLLER)

$(TARGET_CONTROLLER): ../tools/controller.cpp
	$(CXX) -std=c++20 -O2 -Wall -Wextra $< -o $@

daemon: daemon-target
apps: shell-target
shell: shell-target

install: daemon-target polkit-target secret-target shell-target
	mkdir -p $(PREFIX)
	install -m 755 $(TARGET_DAEMON) $(PREFIX)/$(TARGET_DAEMON)
	install -m 755 $(TARGET_POLKIT) $(PREFIX)/$(TARGET_POLKIT)
	install -m 755 $(TARGET_SECRET) $(PREFIX)/$(TARGET_SECRET)
	install -m 755 $(TARGET_SHELL) $(PREFIX)/b1air-shell
	install -m 755 shell/build/b1air-files $(PREFIX)/b1air-files 2>/dev/null || install -m 755 ../tools/b1air-files $(PREFIX)/b1air-files
	install -m 755 shell/build/b1air-settings $(PREFIX)/b1air-settings 2>/dev/null || install -m 755 ../tools/b1air-settings $(PREFIX)/b1air-settings
	install -m 755 shell/build/b1air-monitor $(PREFIX)/b1air-monitor 2>/dev/null || install -m 755 ../tools/b1air-monitor $(PREFIX)/b1air-monitor
	install -m 755 shell/build/b1air-text $(PREFIX)/b1air-text 2>/dev/null || install -m 755 ../tools/b1air-text $(PREFIX)/b1air-text
	install -m 755 shell/build/b1air-term $(PREFIX)/b1air-term 2>/dev/null || install -m 755 ../tools/b1air-term $(PREFIX)/b1air-term
	mkdir -p $(HOME)/.config/b1air-shell
	rsync -a shell/qml/ $(HOME)/.config/b1air-shell/

clean:
	rm -f $(DAEMON_OBJS) $(POLKIT_OBJS) $(SECRET_OBJS) $(TARGET_DAEMON) $(TARGET_POLKIT) $(TARGET_SECRET) $(TARGET_CONTROLLER)
	rm -rf shell/build

.PHONY: all daemon-target polkit-target secret-target shell-target controller daemon apps shell install clean
