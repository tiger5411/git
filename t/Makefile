# Import tree-wide shared Makefile behavior and libraries
include ../shared.mak

# Run tests
#
# Copyright (c) 2005 Junio C Hamano
#

-include ../config.mak.autogen
-include ../config.mak

#GIT_TEST_OPTS = --verbose --debug
SHELL_PATH ?= $(SHELL)
TEST_SHELL_PATH ?= $(SHELL_PATH)
PERL_PATH ?= /usr/bin/perl
TAR ?= $(TAR)
RM ?= rm -f
PROVE ?= prove
DEFAULT_TEST_TARGET ?= test
TEST_LINT ?= test-lint

ifdef TEST_OUTPUT_DIRECTORY
TEST_RESULTS_DIRECTORY = $(TEST_OUTPUT_DIRECTORY)/test-results
else
TEST_RESULTS_DIRECTORY = test-results
endif

# Shell quote;
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))
TEST_SHELL_PATH_SQ = $(subst ','\'',$(TEST_SHELL_PATH))
PERL_PATH_SQ = $(subst ','\'',$(PERL_PATH))
TEST_RESULTS_DIRECTORY_SQ = $(subst ','\'',$(TEST_RESULTS_DIRECTORY))

T = $(sort $(wildcard t[0-9][0-9][0-9][0-9]-*.sh))
TGITWEB = $(sort $(wildcard t95[0-9][0-9]-*.sh))
THELPERS = $(sort $(filter-out $(T),$(wildcard *.sh)))
TPERF = $(sort $(wildcard perf/p[0-9][0-9][0-9][0-9]-*.sh))
CHAINLINT = sed -f chainlint.sed

all: $(DEFAULT_TEST_TARGET)

test: pre-clean check-chainlint $(TEST_LINT)
	$(MAKE) aggregate-results-and-cleanup

failed:
	@failed=$$(cd '$(TEST_RESULTS_DIRECTORY_SQ)' && \
		grep -l '^failed [1-9]' *.counts | \
		sed -n 's/\.counts$$/.sh/p') && \
	test -z "$$failed" || $(MAKE) $$failed

prove: pre-clean check-chainlint $(TEST_LINT)
	@echo "*** prove ***"; $(PROVE) --exec '$(TEST_SHELL_PATH_SQ)' $(GIT_PROVE_OPTS) $(T) :: $(GIT_TEST_OPTS)
	$(MAKE) clean-except-prove-cache

$(T):
	@echo "*** $@ ***"; '$(TEST_SHELL_PATH_SQ)' $@ $(GIT_TEST_OPTS)

pre-clean:
	$(RM) -r '$(TEST_RESULTS_DIRECTORY_SQ)'

clean-except-prove-cache:
	$(RM) -r 'trash directory'.* '$(TEST_RESULTS_DIRECTORY_SQ)'
	$(RM) -r valgrind/bin

clean: clean-except-prove-cache
	$(RM) .prove

clean-chainlint:
	$(RM) -r .build/chainlint

CHAINLINT_TESTS = $(wildcard chainlint/*.test)

CHAINLINT_GEN = $(CHAINLINT_TESTS:%.test=.build/%)

.PRECIOUS: $(CHAINLINT_GEN:%=%/test)
.build/chainlint/%/test: chainlint/%.test
	$(call mkdir_p_parent_template)
	$(QUIET_CHAINLINT_DEP)sed -e '/^# LINT: /d' $< >$@

.PRECIOUS: $(CHAINLINT_GEN:%=%/chainlint)
.build/chainlint/%/chainlint: .build/chainlint/%/test
	$(call mkdir_p_parent_template)
	$(QUIET_CHAINLINT_DEP)$(CHAINLINT) <$< >$@

.PRECIOUS: $(CHAINLINT_GEN:%=%/expect)
.build/chainlint/%/expect: chainlint/%.expect
	$(call mkdir_p_parent_template)
	$(QUIET_CHAINLINT_DEP)sed -e '/^[ 	]*$$/d' $< >$@

.PRECIOUS: $(CHAINLINT_GEN:%=%/actual)
.build/chainlint/%/actual: .build/chainlint/%/chainlint
	$(call mkdir_p_parent_template)
	$(QUIET_CHAINLINT_DEP)grep -v '^[   ]*$$' $< >$@

.build/chainlint/%/ok: .build/chainlint/%/actual .build/chainlint/%/expect
	$(call mkdir_p_parent_template)
	$(QUIET_CHAINLINT)diff -u $(@D)/expect $(@D)/actual >$@

check-chainlint: $(CHAINLINT_GEN:%=%/ok)

test-lint: test-lint-duplicates test-lint-executable test-lint-shell-syntax \
	test-lint-filenames

test-lint-duplicates:
	@dups=`echo $(T) $(TPERF) | tr ' ' '\n' | sed 's/-.*//' | sort | uniq -d` && \
		test -z "$$dups" || { \
		echo >&2 "duplicate test numbers:" $$dups; exit 1; }

test-lint-executable:
	@bad=`for i in $(T) $(TPERF); do test -x "$$i" || echo $$i; done` && \
		test -z "$$bad" || { \
		echo >&2 "non-executable tests:" $$bad; exit 1; }

test-lint-shell-syntax:
	@'$(PERL_PATH_SQ)' check-non-portable-shell.pl $(T) $(THELPERS) $(TPERF)

test-lint-filenames:
	@# We do *not* pass a glob to ls-files but use grep instead, to catch
	@# non-ASCII characters (which are quoted within double-quotes)
	@bad="$$(git -c core.quotepath=true ls-files 2>/dev/null | \
			grep '["*:<>?\\|]')"; \
		test -z "$$bad" || { \
		echo >&2 "non-portable file name(s): $$bad"; exit 1; }

aggregate-results-and-cleanup: $(T)
	$(MAKE) aggregate-results
	$(MAKE) clean

aggregate-results:
	for f in '$(TEST_RESULTS_DIRECTORY_SQ)'/t*-*.counts; do \
		echo "$$f"; \
	done | '$(SHELL_PATH_SQ)' ./aggregate-results.sh

gitweb-test:
	$(MAKE) $(TGITWEB)

valgrind:
	$(MAKE) GIT_TEST_OPTS="$(GIT_TEST_OPTS) --valgrind"

perf:
	$(MAKE) -C perf/ all

.PHONY: pre-clean $(T) aggregate-results clean valgrind perf check-chainlint clean-chainlint
