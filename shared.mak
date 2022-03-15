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
comma := ,
empty :=
space := $(empty) $(empty)

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

	QUIET_MKDIR = @echo '   ' MKDIR $@;
	QUIET_MKDIR_P_PARENT  = @echo '   ' MKDIR -p $(patsubst %/.,%,$(1)$(@D))

## Used in "Makefile"
	QUIET_CC       = @echo '   ' CC $@;
	QUIET_CC_ASM   = @echo '   ' CC \(ASM\) $@;
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
	QUIET_CMP      = @echo '   ' CMP $^;

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
