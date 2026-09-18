# ---- Display info during parsing phase ----
SILENT:=$(findstring s,$(word 1, $(MAKEFLAGS)))
ifneq ($(SILENT),s)
    $(info Using Makefile: $(realpath $(firstword $(MAKEFILE_LIST))) $(MAKECMDGOALS))
endif

# Makefile for the scope merge regression tests

ifneq ($(shell echo),)
  CMD_EXE = 1
endif

ifdef CMD_EXE
  S = $(subst /,\,/)
  NOT = - # Hack
  NULLDEV = nul:
  MKDIR = mkdir $(subst /,\,$1)
  RMDIR = -rmdir /s /q $(subst /,\,$1)
else
  S = /
  NOT = !
  NULLDEV = /dev/null
  MKDIR = mkdir -p $1
  RMDIR = $(RM) -r $1
endif

ifeq ($(SILENT),s)
    QUIET = 1
endif

ifdef QUIET
  .SILENT:
  NULLOUT = >$(NULLDEV)
  NULLERR = 2>$(NULLDEV)
endif

CA65 := $(if $(wildcard ../../../bin/ca65*),..$S..$S..$Sbin$Sca65,ca65)

WORKDIR = ../../../testwrk/asm/scope-merge

.PHONY: all clean

SUCCESS_SOURCES := merge.s merge-include.s nested.s project-includes.s
SUCCESS_TESTS = $(SUCCESS_SOURCES:%.s=$(WORKDIR)/%.o)
FEATURE_TEST = $(WORKDIR)/feature-enable.o
ERROR_SOURCES := duplicate-symbol.s no-option.s
ERROR_TESTS = $(ERROR_SOURCES:%.s=$(WORKDIR)/%.err)

all: $(SUCCESS_TESTS) $(FEATURE_TEST) $(ERROR_TESTS)

$(WORKDIR):
	$(call MKDIR,$(WORKDIR))

$(WORKDIR)/%.o: %.s | $(WORKDIR)
	$(if $(QUIET),echo asm/scope-merge/$*.s)
	$(CA65) --no-utf8 --debug-info --merge-scopes -o $@ $< $(NULLOUT)

$(FEATURE_TEST): feature-enable.s | $(WORKDIR)
	$(if $(QUIET),echo asm/scope-merge/feature-enable.s)
	$(CA65) --no-utf8 --debug-info -o $@ $< $(NULLOUT)

$(WORKDIR)/duplicate-symbol.err: duplicate-symbol.s | $(WORKDIR)
	$(if $(QUIET),echo asm/scope-merge/duplicate-symbol.s)
	$(NOT) $(CA65) --no-utf8 --merge-scopes -o $(@:.err=.o) $< $(NULLOUT) $(NULLERR)

$(WORKDIR)/no-option.err: no-option.s | $(WORKDIR)
	$(if $(QUIET),echo asm/scope-merge/no-option.s)
	$(NOT) $(CA65) --no-utf8 -o $(@:.err=.o) $< $(NULLOUT) $(NULLERR)

clean:
	@$(call RMDIR,$(WORKDIR))
