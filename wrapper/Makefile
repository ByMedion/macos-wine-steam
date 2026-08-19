#
# Cross-compile the steamwebhelper wrapper from macOS for Windows x86_64.
#
#   make         build ./steamwebhelper.exe
#   make clean   remove build artefacts
#
# Requires Homebrew's mingw-w64 toolchain:
#   brew install mingw-w64
#
# Normally you do not invoke this directly -- build-wrapper.sh does it for you.

TARGET  ?= steamwebhelper.exe
CC      ?= x86_64-w64-mingw32-gcc
CFLAGS  ?= -O2 -Wall -Wextra -municode -DUNICODE -D_UNICODE
LDFLAGS ?= -static -lshell32 -mwindows
SRC      = src/steamwebhelper-wrapper.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGET)
