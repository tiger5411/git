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

## make-CQ_SQ-vars: Convenience wrapper for $(make-fn-sfx-vars,CQ_SQ,shq_Csq,$(1))
## => $(eval $(call make-CQ_SQ-vars,X Y) => makes $(X_CQ_SQ) and $(Y_CQ_SQ)
define make-CQ_SQ-vars
$(call make-fn-sfx-vars,CQ_SQ,shq_Csq,$(1))
endef

### Global variables

## comma, empty, space: handy variables as these tokens are either
## special or can be hard to spot among other Makefile syntax.
comma = ,
empty =
space = $(empty) $(empty)
