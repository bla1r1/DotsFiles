CXX ?= ccache g++

# `CC ?=` loses to make's own built-in default, so ccache never got used for the
# 9.5 MB amalgamation. An explicit command-line CC= still wins over this.
ifeq ($(origin CC),default)
CC = ccache gcc
endif
# -Ithird_party puts the vendored nlohmann/json.hpp ahead of the system one,
# so the build no longer needs a distribution package for a single header.
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread -Idaemon -Ithird_party -Ithird_party/sqlite
LDFLAGS = -lsystemd -lcrypto

# SQLite is compiled in from third_party/sqlite rather than linked against the
# system libsqlite3, so b1air-daemon carries its own copy and does not depend on
# whatever version the distribution happens to ship. The amalgamation is what
# upstream publishes for exactly this, and it is public domain.
#
# Built as C with its own flags: the amalgamation is not warning-clean under the
# -Wall -Wextra we hold our own code to, and there is no value in auditing
# upstream's warnings on every build.
SQLITE_OBJ = third_party/sqlite/sqlite3.o
SQLITE_CFLAGS = -O2 -w -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION=1 \
                -DSQLITE_DQS=0 -DSQLITE_DEFAULT_MEMSTATUS=0 \
                -DSQLITE_LIKE_DOESNT_MATCH_BLOBS -DSQLITE_MAX_EXPR_DEPTH=0
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

$(TARGET_DAEMON): $(DAEMON_OBJS) $(SQLITE_OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(TARGET_POLKIT): $(POLKIT_OBJS) $(SQLITE_OBJ)
	$(CXX) $(CXXFLAGS) $(POLKIT_CFLAGS) -o $@ $^ $(LDFLAGS) $(POLKIT_LIBS)

$(TARGET_SECRET): $(SECRET_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ -lcrypto

$(SQLITE_OBJ): third_party/sqlite/sqlite3.c
	$(CC) $(SQLITE_CFLAGS) -c $< -o $@

# -MMD -MP writes a .d file beside each object listing the headers it included,
# and the -include below feeds those back to make. Without them a header change
# rebuilt nothing: editing proc_util.hpp or system_control.hpp left every object
# that includes it untouched, make reported success, and the binary that came
# out was the old one. That is not a theoretical hazard — it happened during
# this work, and the only symptom was a fix that appeared not to work.
daemon/%.o: daemon/%.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP $(if $(filter daemon/polkit_agent_main.cpp,$<),$(POLKIT_CFLAGS),) -c $< -o $@

-include $(DAEMON_OBJS:.o=.d) $(POLKIT_OBJS:.o=.d) $(SECRET_OBJS:.o=.d)

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
	# ponytail: install whatever cmake built, so new apps need no edit here
	for f in shell/build/b1air-*; do test -x "$$f" && install -m 755 "$$f" $(PREFIX)/ || true; done
	install -m 755 $(TARGET_DAEMON) $(PREFIX)/$(TARGET_DAEMON)
	install -m 755 $(TARGET_POLKIT) $(PREFIX)/$(TARGET_POLKIT)
	install -m 755 $(TARGET_SECRET) $(PREFIX)/$(TARGET_SECRET)
	mkdir -p $(HOME)/.config/b1air-shell
	rsync -a shell/qml/ $(HOME)/.config/b1air-shell/

clean:
	rm -f $(DAEMON_OBJS) $(SQLITE_OBJ) $(POLKIT_OBJS) $(SECRET_OBJS) $(TARGET_DAEMON) $(TARGET_POLKIT) $(TARGET_SECRET) $(TARGET_CONTROLLER)
	rm -f $(DAEMON_OBJS:.o=.d) $(POLKIT_OBJS:.o=.d) $(SECRET_OBJS:.o=.d)
	rm -rf shell/build

.PHONY: all daemon-target polkit-target secret-target shell-target controller daemon apps shell install clean
