### Flags affecting all rules

# A GNU make extension since gmake 3.72 (released in late 1994) to
# remove the target of rules if commands in those rules fail. The
# default is to only do that if make itself receives a signal. Affects
# all targets, see:
#
#    info make --index-search=.DELETE_ON_ERROR
.DELETE_ON_ERROR:

### Templates

# Template for making a GIT-SOMETHING, which changes if a
# TRACK_SOMETHING variable changes.
define TRACK_template
.PHONY: FORCE
$(1): FORCE
	@FLAGS='$($(2))'; \
	if ! test -f $(1) ; then \
		echo >&2 "    $(1) PARAMETERS (new)" $@; \
		echo "$$$$FLAGS" >$(1); \
	elif test x"$$$$FLAGS" != x"`cat $(1) 2>/dev/null`" ; then \
		echo >&2 "    $(1) PARAMETERS (parameters changed)" $@; \
		echo "$$$$FLAGS" >$(1); \
	fi
endef
