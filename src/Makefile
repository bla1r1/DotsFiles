CXX = g++
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread
LDFLAGS = -lsqlite3

TARGET = b1air-daemon
PREFIX ?= $(HOME)/.local/bin

SRCS = main.cpp sway_ipc.cpp focustime_db.cpp user_manager.cpp system_control.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

install: $(TARGET)
	mkdir -p $(PREFIX)
	install -m 755 $(TARGET) $(PREFIX)/$(TARGET)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all install clean
