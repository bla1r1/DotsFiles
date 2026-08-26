CXX ?= ccache g++
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread
LDFLAGS = -lsqlite3

TARGET_DAEMON = b1air-daemon
TARGET_SHELL = shell/build/b1air-shell
PREFIX ?= $(HOME)/.local/bin

SRCS = main.cpp sway_ipc.cpp focustime_db.cpp user_manager.cpp system_control.cpp settings_manager.cpp session_manager.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(TARGET_DAEMON) shell-target

$(TARGET_DAEMON): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

shell-target:
	cmake -B shell/build shell
	cmake --build shell/build -j4

install: $(TARGET_DAEMON) shell-target
	mkdir -p $(PREFIX)
	install -m 755 $(TARGET_DAEMON) $(PREFIX)/$(TARGET_DAEMON)
	install -m 755 $(TARGET_SHELL) $(PREFIX)/b1air-shell
	mkdir -p $(HOME)/.config/b1air-shell
	rsync -a shell/qml/ $(HOME)/.config/b1air-shell/

clean:
	rm -f $(OBJS) $(TARGET_DAEMON)
	rm -rf shell/build

.PHONY: all shell-target install clean
