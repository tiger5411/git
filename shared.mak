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
