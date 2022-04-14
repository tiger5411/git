### Remove GNU make implicit rules

## This speeds things up since we don't need to look for and stat() a
## "foo.c,v" every time a rule referring to "foo.c" is in play. See
## "make -p -f/dev/null | grep ^%::'".
%:: %,v
%:: RCS/%,v
%:: RCS/%
%:: s.%
%:: SCCS/s.%

## Likewise delete default $(SUFFIXES). See:
##
##     info make --index-search=.SUFFIXES
.SUFFIXES:

### Flags affecting all rules

# A GNU make extension since gmake 3.72 (released in late 1994) to
# remove the target of rules if commands in those rules fail. The
# default is to only do that if make itself receives a signal. Affects
# all targets, see:
#
#    info make --index-search=.DELETE_ON_ERROR
.DELETE_ON_ERROR:

### GNU Make version detection
# We don't care about "release" versions like the "90" in "3.99.90"
MAKE_VERSION_MAJOR = $(word 1,$(subst ., ,$(MAKE_VERSION)))
MAKE_VERSION_MINOR = $(word 2,$(subst ., ,$(MAKE_VERSION)))

# The oldest supported version of GNU make is 3-something. So "not v3"
# is a future-proof way to ask "is it modern?"
ifneq ($(MAKE_VERSION_MAJOR),3)
# $(file >[...]) and $(file >>[...]) is in 4.0...
MAKE_HAVE_FILE_WRITE = Need version 4.0 or later (released in late 2013)
# .. but we need 4.2 for $(file <[...])
ifneq ($(filter-out 0 1,$(MAKE_VERSION_MINOR)),)
MAKE_HAVE_FILE_READ = Need version 4.2 or later (released in mid-2016)
endif
endif

### Quoting helpers

## shq ([s]hell[q]quote):
## => Quote a ' inside a '': X_SQ='$(call shq,$(X))'
shq = $(subst ','\'',$(1))
#' (balance quotes for makefile-mode.el)

## shqq ([s]hell[q]uote[q]uote)
## => Quote a ' and provide a '': X_SQ=$(call shqq,$(X))
## => Equivalent to: X_SQQ='$(call shq,$(X))'
shqq = '$(call shq,$(1))'

# Cq ([C][q]uote):
## => Quote " and \ for use inside a " C-string
Cq = $(subst ",\",$(subst \,\\,$(1)))
#" (balance quotes for makefile-mode.el)

## shq_Csq ([s]hell[q]uote_[C][s]tring[q]uote):
## => Add surrounding "" for C, escape the contents: -DX='$(call shq_Csq,$(X))'
shq_Csq = "$(call shq,$(call Cq,$(1)))"

## shqq_Csq ([s]hell[q]uote[quote]_[C][q]uote):
## => Add surrounding "" for C, as well as ' for the shell: -DX=$(call shqq_Cq,$(X))
## => Equivalent to: -DX=$(call shq,$(call shq_Cq,$(X)))
shqq_Cq = '$(call shq_Csq,$(1))'

## make-fn-sfx-vars: make N number of X_<sfx>, Y_<sfx>, ... vars from X Y with <fn>
## => make X_SQ and Y_SQ quoted with "shq":
## => $(eval $(call make-fn-sfx-vars,SQ,shq,X Y))
define make-fn-sfx-vars
$(foreach v,$(3),\
$(v)_$(1) = $$(call $(2),$$($(v)))
)
endef

## make-SQ-vars: Convenience wrapper for $(make-fn-sfx-vars,SQ,shq,$(1))
## => $(eval $(call make-SQ-vars,X Y) => makes $(X_SQ) and $(Y_SQ)
define make-SQ-vars
$(call make-fn-sfx-vars,SQ,shq,$(1))
endef

## make-SQ_CQS-vars: Convenience wrapper for $(make-fn-sfx-vars,SQ_CQS,shqq_Cq,$(1))
## => $(eval $(call make-SQ_CQS-vars,X Y) => makes $(X_SQ_CQS) and $(Y_SQ_CQS)
define make-SQ_CQS-vars
$(call make-fn-sfx-vars,SQ_CQS,shqq_Cq,$(1))
endef

### Global variables

## comma, empty, space: handy variables as these tokens are either
## special or can be hard to spot among other Makefile syntax.
comma := ,
empty :=
space := $(empty) $(empty)

## wspfx: the whitespace prefix padding for $(QUIET...) and similarly
## aligned output.
wspfx = $(space)$(space)$(space)
wspfx_SQ = '$(subst ','\'',$(wspfx))'
# ' closing quote to appease Emacs make-mode.elxo

### Quieting
## common
QUIET_SUBDIR0  = +$(MAKE) -C # space to separate -C and subdir
QUIET_SUBDIR1  =

ifneq ($(findstring w,$(MAKEFLAGS)),w)
PRINT_DIR = --no-print-directory
else # "make -w"
NO_SUBDIR = :
endif

ifneq ($(findstring s,$(MAKEFLAGS)),s)
ifndef V
## common
	QUIET_SUBDIR0  = +@subdir=
	QUIET_SUBDIR1  = ;$(NO_SUBDIR) echo $(wspfx_SQ) SUBDIR $$subdir; \
			 $(MAKE) $(PRINT_DIR) -C $$subdir

	QUIET          = @
	QUIET_GEN      = @echo $(wspfx_SQ) GEN $@;

	QUIET_MKDIR = @echo '   ' MKDIR $@;
	QUIET_MKDIR_P_PARENT  = @echo '   ' MKDIR -p $(patsubst %/.,%,$(1)$(@D))

## Used in "Makefile"

	QUIET_CC       = @echo $(wspfx_SQ) CC $@;
	QUIET_CC_ASM   = @echo $(wspfx_SQ) CC \(ASM\) $@;
	QUIET_AR       = @echo $(wspfx_SQ) AR $@;
	QUIET_LINK     = @echo $(wspfx_SQ) LINK $@;
	QUIET_BUILT_IN = @echo $(wspfx_SQ) BUILTIN $@;
	QUIET_CP       = @echo '   ' CP $@;
	QUIET_LNCP     = @echo $(wspfx_SQ) LN/CP $@;
	QUIET_XGETTEXT = @echo $(wspfx_SQ) XGETTEXT $@;
	QUIET_MSGINIT  = @echo '   ' MSGINIT $@;
	QUIET_MSGFMT   = @echo $(wspfx_SQ) MSGFMT $@;
	QUIET_GCOV     = @echo $(wspfx_SQ) GCOV $@;
	QUIET_SP       = @echo $(wspfx_SQ) SP $<;
	QUIET_HDR      = @echo $(wspfx_SQ) HDR $(<:hcc=h);
	QUIET_RC       = @echo $(wspfx_SQ) RC $@;
	QUIET_SPATCH   = @echo $(wspfx_SQ) SPATCH $<;
	QUIET_CHECK    = @echo $(wspfx_SQ) CHECK $@;
	QUIET_CMP      = @echo $(wspfx_SQ) CMP $^;

## Used in "Makefile" for po/
	QUIET_CHECK_MSGCAT	= @echo '   ' MSGCAT $(MSGCAT_CHECK_FLAGS) $< \>$@;
	QUIET_CHECK_PO		= @echo '   ' CHECK PO $@;
	QUIET_PO_INIT		= @echo '   ' PO INIT $@;

## Used in "Documentation/Makefile"
	QUIET_ASCIIDOC	= @echo $(wspfx_SQ) ASCIIDOC $@;
	QUIET_XMLTO	= @echo $(wspfx_SQ) XMLTO $@;
	QUIET_DB2TEXI	= @echo $(wspfx_SQ) DB2TEXI $@;
	QUIET_MAKEINFO	= @echo $(wspfx_SQ) MAKEINFO $@;
	QUIET_DBLATEX	= @echo $(wspfx_SQ) DBLATEX $@;
	QUIET_XSLTPROC	= @echo $(wspfx_SQ) XSLTPROC $@;
	QUIET_GEN	= @echo $(wspfx_SQ) GEN $@;
	QUIET_STDERR	= 2> /dev/null

	QUIET_LINT_GITLINK	= @echo $(wspfx_SQ) LINT GITLINK $<;
	QUIET_LINT_MANSEC	= @echo $(wspfx_SQ) LINT MAN SEC $<;
	QUIET_LINT_MANEND	= @echo $(wspfx_SQ) LINT MAN END $<;

## Used in "t/Makefile"
	QUIET_CHAINLINT		= @echo '   ' CHAINLINT $@;
	QUIET_CHAINLINT_DEP	= @echo '   ' CHAINLINT DEP $@;

	export V
endif
endif

### Templates

## mkdir_p_prefix_parent: See "mkdir_p_parent" below. This adds an
## optional prefix to the $(@D) parent, to e.g. create a derived file
## in .build/. A $(patsubst) in the $(QUIET_MKDIR_P_PARENT) turns ugly
## paths like "dep/." into "dep".
define mkdir_p_prefix_parent_template
$(if $(wildcard $(1)$(@D)),,$(QUIET_MKDIR_P_PARENT)$(shell mkdir -p $(1)$(@D)))
endef

## mkdir_p_parent: lazily "mkdir -p" the path needed for a $@
## file. Uses $(wildcard) to avoid the "mkdir -p" if it's not
## needed.
##
## Is racy, but in a good way; we might redundantly (and safely)
## "mkdir -p" when running in parallel, but won't need to exhaustively create
## individual rules for "a" -> "prefix" -> "dir" -> "file" if given a
## "a/prefix/dir/file". This can instead be inserted at the start of
## the "a/prefix/dir/file" rule.
define mkdir_p_parent_template
$(call mkdir_p_prefix_parent_template)
endef

## check-sorted-file-rule: make a "check" rule to see if a given file
## is sorted. The $(2) is run at most twice, with "sorted" being
## determined by "LC_ALL=C sort". Scratch files are created under
## .build/$(1)/
##
##	$(1) = The rule name, e.g. 'check-sorted-stuff'
##	$(2) = A filtering command to run on the file, e.g. "cat" or "grep ::"
##	$(3) = The filename, e.g. stuff.txt
##	$(4) = A command taking sorted/unsorted versions, to check if
##	       they're the same, use e.g. "cmp" or "diff -u"
define check-sorted-file-rule
.build/$(1)/expect: $(3)
	$$(call mkdir_p_parent_template)
	$$(QUIET_GEN)$(2) $(3) | LC_ALL=C sort >$$@

.build/$(1)/actual: $(3)
	$$(call mkdir_p_parent_template)
	$$(QUIET_GEN)$(2) $(3) >$$@

.build/$(1)/ok: .build/$(1)/expect
.build/$(1)/ok: .build/$(1)/actual
.build/$(1)/ok:
	$$(QUIET_CMP)$(4) $$^ && \
	>$$@

$(1): .build/$(1)/ok
.PHONY: $(1)
endef

## TRACK_template: maintain a GIT-SOMETHING file, which changes if a
## TRACK_SOMETHING variable changes.
##
## This is the slower version used on GNU make <4.2.
ifndef MAKE_HAVE_FILE_READ

define TRACK_template
.PHONY: FORCE
$(1): FORCE
	@FLAGS=$$(call shqq,$$($(2))); \
	if ! test -f $(1) ; then \
		echo $(wspfx_SQ) "$(1) PARAMETERS (new)"; \
		printf "%s\n" "$$$$FLAGS" >$(1); \
	elif test x"$$$$FLAGS" != x"`cat $(1) 2>/dev/null`" ; then \
		echo $(wspfx_SQ) "$(1) PARAMETERS (changed)"; \
		printf "%s\n" "$$$$FLAGS" >$(1); \
	fi
endef

endif # !MAKE_HAVE_FILE_READ

## A TRACK_template template compatible with the one above. Uses
## features of GNU make >=4.2 to avoid shelling out for this "hot"
## "FORCE" logic.
##
## Since version >=4.2 can do both "I" and "O" in I/O with using
## $(file <)/$(file >) we read the GIT-SOMETHING file into a variable
## with the former, and if it's different from our expected value
## write it out with the latter.
ifdef MAKE_HAVE_FILE_READ

define TRACK_template_eval
$(1)_WRITE =
$(1)_EXISTS = $(wildcard $(1))
ifeq ($$($(1)_EXISTS),)
$(1)_WRITE = new
else
$(1)_CONTENT = $(file <$(1))
ifeq ($$($(1)_CONTENT),$($(2)))
$(1)_WRITE = same
else
$(1)_WRITE = changed
endif
endif
ifneq ($$($(1)_WRITE),same)
$$(info $$(wspfx) $(1) parameters ($$($(1)_WRITE)))
$$(file >$(1),$($(2)))
endif
endef # TRACK_template_eval

define TRACK_template
.PHONY: FORCE
$(1): FORCE
	$$(eval $$(call TRACK_template_eval,$(1),$(2)))
endef

endif # MAKE_HAVE_FILE_READ

## Define $(GOAL_STANDALONE) if the goal is known to be a "standalone"
## goal that doesn't need to include things, run $(shell) commands to
## figure out what to feed to a $(CC) etc. Examples include "clean",
## "lint-docs" etc. Also provides the inverse of
## $(GOAL_NOT_STANDALONE) for convenience.

# Assume that we're not standalone by default
GOAL_NOT_STANDALONE = Assuming so, with goals: '$(MAKECMDGOALS)'
ifeq ($(MAKECMDGOALS),)
GOAL_NOT_STANDALONE = Yes, default target
else
# Default targets that don't need do do any compilation, in addition
# to any defined before shared.mak was included.
STANDALONE_TARGETS += clean
STANDALONE_TARGETS += distclean

GOALS_WITHOUT_STANDALONE = $(filter-out $(STANDALONE_TARGETS),$(MAKECMDGOALS))
ifeq ($(GOALS_WITHOUT_STANDALONE),)
GOAL_NOT_STANDALONE =
endif
endif
# It was easier to define the inverse above, but provide
# $(GOAL_STANDALONE) for use
ifdef GOAL_NOT_STANDALONE
GOAL_STANDALONE =
else
GOAL_STANDALONE = Had only stand-alone goals: '$(MAKECMDGOALS)'
endif
