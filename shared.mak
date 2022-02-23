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

### Global variables

## comma, empty, space: handy variables as these tokens are either
## special or can be hard to spot among other Makefile syntax.
comma = ,
empty =
space = $(empty) $(empty)

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

### Templates

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
$(if $(wildcard $(@D)),,$(QUIET_MKDIR_P_PARENT)$(shell mkdir -p $(@D)))
endef
