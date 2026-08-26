CXX ?= g++
CXXFLAGS ?= -std=c++20 -O3 -Wall -Wextra -pedantic
LDFLAGS ?= -lsqlite3

TARGET = b1air-daemon
SRCS = main.cpp sway_ipc.cpp focustime_db.cpp user_manager.cpp
OBJS = $(SRCS:.cpp=.o)

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

install: $(TARGET)
	install -d -m 755 $(BINDIR)
	install -m 755 $(TARGET) $(BINDIR)/$(TARGET)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all install clean
