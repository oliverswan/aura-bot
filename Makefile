SHELL = /bin/sh
SYSTEM = $(shell uname)
ARCH = $(shell uname -m)
INSTALL_DIR = /usr

ifndef CC
  CC = gcc
endif

ifndef CXX
  CXX = g++
endif

CCFLAGS = -fno-builtin
CXXFLAGS = -std=c++14 -pipe -Wall -Wextra -fno-builtin -fno-rtti
DFLAGS =
OFLAGS = -O3 -flto
# war3plat: prefer the in-tree dependency builds from `make deps` (no `sudo make install` needed);
# fall back to a system-wide StormLib (`-lstorm`) as upstream does. The rpath lets aura++ find the
# in-tree .so files from any working directory without LD_LIBRARY_PATH.
ifneq ($(wildcard StormLib/libStorm.so),)
  STORM_LFLAGS = -LStormLib -lStorm
else
  STORM_LFLAGS = -lstorm
endif
LFLAGS = -L. -L/usr/local/lib/ -Lbncsutil/src/bncsutil/ $(STORM_LFLAGS) -lbncsutil -lgmp -lbz2 -lz \
         -Wl,-rpath,'$$ORIGIN/StormLib:$$ORIGIN/bncsutil/src/bncsutil'

ifeq ($(ARCH),x86_64)
	CCFLAGS += -m64
	CXXFLAGS += -m64
endif

ifeq ($(SYSTEM),Darwin)
	INSTALL_DIR = /usr/local
	CXXFLAGS += -stdlib=libc++
	CC = clang
	CXX = clang++
	DFLAGS += -D__APPLE__
else
	LFLAGS += -lrt
endif

ifeq ($(SYSTEM),FreeBSD)
	DFLAGS += -D__FREEBSD__
endif

ifeq ($(SYSTEM),SunOS)
	DFLAGS += -D__SOLARIS__
	LFLAGS += -lresolv -lsocket -lnsl
endif

CCFLAGS += $(OFLAGS) -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION -I.
CXXFLAGS += $(OFLAGS) $(DFLAGS) -I. -Ibncsutil/src/ -IStormLib/src/

OBJS = src/bncsutilinterface.o \
			 src/bnet.o \
			 src/bnetprotocol.o \
			 src/config.o \
			 src/crc32.o \
			 src/csvparser.o \
			 src/game.o \
			 src/gameplayer.o \
			 src/gameprotocol.o \
			 src/gameslot.o \
			 src/gpsprotocol.o \
			 src/aura.o \
			 src/auradb.o \
			 src/map.o \
			 src/sha1.o \
			 src/socket.o \
			 src/stats.o \
			 src/irc.o \
			 src/fileutil.o

COBJS = src/sqlite3.o

PROG = aura++

all: $(OBJS) $(COBJS) $(PROG)
	@echo "Used CFLAGS: $(CXXFLAGS)"

$(PROG): $(OBJS) $(COBJS)
	@$(CXX) -o aura++ $(OBJS) $(COBJS) $(CXXFLAGS) $(LFLAGS)
	@echo "[BIN] $@ created."
	@strip "$(PROG)"
	@echo "[BIN] Stripping the binary."

# war3plat: build StormLib and bncsutil in-tree. Run as a separate step: `make deps && make`
# (the library detection above happens when make starts).
deps:
	$(MAKE) -C StormLib -f Makefile.linux libStorm.so
	$(MAKE) -C bncsutil/src/bncsutil

clean:
	@rm -f $(OBJS) $(COBJS) $(PROG)
	@echo "Binary and object files cleaned."

install:
	@install -d "$(DESTDIR)$(INSTALL_DIR)/bin"
	@install $(PROG) "$(DESTDIR)$(INSTALL_DIR)/bin/$(PROG)"
	@echo "Binary $(PROG) installed to $(DESTDIR)$(INSTALL_DIR)/bin"

$(OBJS): %.o: %.cpp
	@$(CXX) -o $@ $(CXXFLAGS) -c $<
	@echo "[$(CXX)] $@"

$(COBJS): %.o: %.c
	@$(CC) -o $@ $(CCFLAGS) -c $<
	@echo "[$(CC)] $@"

clang-tidy:
	@for file in $(OBJS); do \
		clang-tidy "src/$$(basename $$file .o).cpp" -fix -checks=* -header-filter=src/* -- $(CXXFLAGS) $(DFLAGS); \
	done;
