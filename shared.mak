### Flags affecting all rules

# A GNU make extension since gmake 3.72 (released in late 1994) to
# remove the target of rules if commands in those rules fail. The
# default is to only do that if make itself receives a signal. Affects
# all targets, see:
#
#    info make --index-search=.DELETE_ON_ERROR
.DELETE_ON_ERROR:

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
	QUIET_SUBDIR1  = ;$(NO_SUBDIR) echo '   ' SUBDIR $$subdir; \
			 $(MAKE) $(PRINT_DIR) -C $$subdir

	QUIET          = @
	QUIET_GEN      = @echo '   ' GEN $@;

## Used in "Makefile"
	QUIET_CC       = @echo '   ' CC $@;
	QUIET_AR       = @echo '   ' AR $@;
	QUIET_LINK     = @echo '   ' LINK $@;
	QUIET_BUILT_IN = @echo '   ' BUILTIN $@;
	QUIET_LNCP     = @echo '   ' LN/CP $@;
	QUIET_XGETTEXT = @echo '   ' XGETTEXT $@;
	QUIET_MSGFMT   = @echo '   ' MSGFMT $@;
	QUIET_GCOV     = @echo '   ' GCOV $@;
	QUIET_SP       = @echo '   ' SP $<;
	QUIET_HDR      = @echo '   ' HDR $(<:hcc=h);
	QUIET_RC       = @echo '   ' RC $@;
	QUIET_SPATCH   = @echo '   ' SPATCH $<;

## Used in "Documentation/Makefile"
	QUIET_ASCIIDOC	= @echo '   ' ASCIIDOC $@;
	QUIET_XMLTO	= @echo '   ' XMLTO $@;
	QUIET_DB2TEXI	= @echo '   ' DB2TEXI $@;
	QUIET_MAKEINFO	= @echo '   ' MAKEINFO $@;
	QUIET_DBLATEX	= @echo '   ' DBLATEX $@;
	QUIET_XSLTPROC	= @echo '   ' XSLTPROC $@;
	QUIET_GEN	= @echo '   ' GEN $@;
	QUIET_STDERR	= 2> /dev/null

	QUIET_LINT_GITLINK	= @echo '   ' LINT GITLINK $<;
	QUIET_LINT_MANSEC	= @echo '   ' LINT MAN SEC $<;
	QUIET_LINT_MANEND	= @echo '   ' LINT MAN END $<;

	export V
endif
endif

### Templates

## Template for making a GIT-SOMETHING, which changes if a
## TRACK_SOMETHING variable changes.
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
