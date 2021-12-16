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
##     info make --index-search=.DELETE_ON_ERROR
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
comma = ,
empty =
space = $(empty) $(empty)

## wspfx: the whitespace prefix padding for $(QUIET...) and similarly
## aligned output.
wspfx = $(space)$(space)$(space)
wspfx_SQ = $(call shqq,$(wspfx))

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

	QUIET_MKDIR_P_PARENT  = @echo $(wspfx_SQ) MKDIR -p $(@D);

## Used in "Makefile"
	QUIET_CC       = @echo $(wspfx_SQ) CC $@;
	QUIET_AR       = @echo $(wspfx_SQ) AR $@;
	QUIET_LINK     = @echo $(wspfx_SQ) LINK $@;
	QUIET_BUILT_IN = @echo $(wspfx_SQ) BUILTIN $@;
	QUIET_LNCP     = @echo $(wspfx_SQ) LN/CP $@;
	QUIET_XGETTEXT = @echo $(wspfx_SQ) XGETTEXT $@;
	QUIET_MSGFMT   = @echo $(wspfx_SQ) MSGFMT $@;
	QUIET_GCOV     = @echo $(wspfx_SQ) GCOV $@;
	QUIET_SP       = @echo $(wspfx_SQ) SP $<;
	QUIET_HDR      = @echo $(wspfx_SQ) HDR $(<:hcc=h);
	QUIET_RC       = @echo $(wspfx_SQ) RC $@;
	QUIET_SPATCH   = @echo $(wspfx_SQ) SPATCH $<;

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

	export V
endif
endif

## Helpers
define mkdir_p_parent_template
$(if $(wildcard $(@D)),,$(QUIET_MKDIR_P_PARENT)$(shell mkdir -p $(@D)))
endef

### Templates

## Template for making a GIT-SOMETHING, which changes if a
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
