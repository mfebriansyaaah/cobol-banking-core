# Incremental parallel build for the COBOL MySQL backend.
#
# Background: the previous build.sh compiled all ~605 COBOL modules plus the
# C bridge in ONE `cobc` invocation (~7.5 min, single-threaded, full rebuild
# every time). This Makefile compiles each module to an object file once and
# relinks only when inputs changed:
#   clean build : ~3 min with -j4 (vs ~7.5 min single-shot)
#   warm build  : <1 s (nothing to do)
#   one module  : ~5 s (one compile + link)
#
# Usage (always from the repo root; ./build.sh does this for you):
#   make -f cobol/Makefile [-jN]   incremental build (default target: all)
#   make -f cobol/Makefile clean   remove object files (binary kept)
#   make -f cobol/Makefile rebuild clean + build
#   make -f cobol/Makefile smoke   PING smoke test (needs a live database)
#   make -f cobol/Makefile print-jobs
#   make -f cobol/Makefile print-sources
#
# New modules are picked up automatically via wildcard: adding a new
# cobol/src/*_core.cob needs NO Makefile change. The explicit source list for
# the BUILD_LEGACY=1 fallback lives in build.sh; check_manifest.mjs and
# scripts/ci/coverage.sh grep that list, so regenerate it with print-sources
# when adding/removing modules.

COBC      ?= cobc
CC        ?= cc
COB_FLAGS := -free -I cobol/copy -O2
# NOTE: no -Wall -Wextra here. The legacy single-shot build passed those
# flags to cobc (COBOL diagnostics), never to the C compiler, so C objects
# were always built warning-free by default. Adding -Wall to `cc` surfaces
# 6 pre-existing sql_bridge.c notes and trips the warning ratchet.
C_FLAGS   := -O2 -I cobol/c_lib
LD_LIBS   := -L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread

BIN       := cobol/bin/main_logic
OBJ_DIR   := cobol/build/obj
COBJ_DIR  := cobol/build/cobj
COPY_DEPS := $(wildcard cobol/copy/*.cpy)
C_HDRS    := $(wildcard cobol/c_lib/*.h)

MAIN_COB  := cobol/src/main_logic.cob
COB_SRCS  := $(filter-out $(MAIN_COB),$(wildcard cobol/src/*.cob))
COB_OBJS  := $(patsubst cobol/src/%.cob,$(OBJ_DIR)/%.o,$(COB_SRCS))

C_SRCS    := cobol/src/sql_bridge.c $(wildcard cobol/c_lib/*.c)
C_OBJS    := $(patsubst %.c,$(COBJ_DIR)/%.o,$(notdir $(C_SRCS)))

vpath %.c cobol/src cobol/c_lib

.PHONY: all clean rebuild smoke print-jobs print-sources

.DELETE_ON_ERROR:

all: $(BIN)

$(BIN): $(MAIN_COB) $(COB_OBJS) $(C_OBJS) $(COPY_DEPS) cobol/Makefile
	@mkdir -p $(dir $@)
	$(COBC) -x $(COB_FLAGS) -o $@ $(MAIN_COB) $(COB_OBJS) $(C_OBJS) $(LD_LIBS) -Wall -Wextra
	chmod +x $@

$(OBJ_DIR)/%.o: cobol/src/%.cob $(COPY_DEPS) cobol/Makefile
	@mkdir -p $(dir $@)
	$(COBC) $(COB_FLAGS) -c -o $@ $<

$(COBJ_DIR)/%.o: %.c $(C_HDRS) cobol/Makefile
	@mkdir -p $(dir $@)
	$(CC) $(C_FLAGS) -c -o $@ $<

clean:
	rm -rf cobol/build

rebuild: clean all

# PING smoke test. Needs a live database (PING returns DB_DOWN without one),
# so this is NOT part of `all`; tests/run_all.sh runs its own smoke step.
smoke: $(BIN)
	printf 'PING||||||\n' > input.txt
	./$(BIN)
	grep -q 'SUCCESS|PONG' output.txt

print-jobs:
	@echo "nproc: $(shell nproc 2>/dev/null || echo unknown)"
	@echo "cob sources: $(words $(COB_SRCS))"
	@echo "c sources: $(words $(C_SRCS))"

print-sources:
	@echo "$(COB_SRCS) $(MAIN_COB)" | tr ' ' '\n' | sort | sed 's/^/    /;s/$$/ \\/'
