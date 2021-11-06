### Flags affecting all rules

# A GNU make extension since gmake 3.72 (released in late 1994) to
# remove the target of rules if commands in those rules fail. The
# default is to only do that if make itself receives a signal. Affects
# all targets, see:
#
#    info make --index-search=.DELETE_ON_ERROR
.DELETE_ON_ERROR:

### Quoting helpers

## Quote a ' inside a '': FOO='$(call shq,$(BAR))'
shq = $(subst ','\'',$(1))

## Quote a ' and provide a '': FOO=$(call shq,$(BAR))
shellquote = '$(call shq,$(1))'

## Quote a " inside a ""
shdq = $(subst ",\",$(1))

## Quote ' for the shell, and embedded " for C: -DFOO=$(call shelldquote,$(BAR))
shelldquote = '"$(call shdq,$(call shq,$(1)))"'

### Global variables

## comma, empty, space: handy variables as these tokens are either
## special or can be hard to spot among other Makefile syntax.
comma = ,
empty =
space = $(empty) $(empty)

## wspfx: the whitespace prefix padding for $(QUIET...) and similarly
## aligned output.
wspfx = $(space)$(space)$(space)
wspfx_sq = $(call shellquote,$(wspfx))

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
	@FLAGS='$$($(2))'; \
	if ! test -f $(1) ; then \
		echo $(wspfx_sq) "$(1) PARAMETERS (new)"; \
		echo "$$$$FLAGS" >$(1); \
	elif test x"$$$$FLAGS" != x"`cat $(1) 2>/dev/null`" ; then \
		echo $(wspfx_sq) "$(1) PARAMETERS (changed)"; \
		echo "$$$$FLAGS" >$(1); \
	fi
endef
