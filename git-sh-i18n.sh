#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#
# This is Git's interface to gettext.sh. Use it right after
# git-sh-setup as:
#
#   . git-sh-setup
#   . git-sh-i18n
#
#   # For constant interface messages:
#   gettext "A message for the user"; echo
#
#   # To interpolate variables:
#   details="oh noes"
#   eval_gettext "An error occured: \$details"; echo
#
# See "info '(gettext)sh'" for the full manual.

# Try to use libintl's gettext.sh, or fall back to English if we
# can't.
. gettext.sh

if test $? -eq 0 && test -z "$GIT_INTERNAL_GETTEXT_TEST_FALLBACKS"
then
	TEXTDOMAIN=git
	export TEXTDOMAIN
	if [ -z "$GIT_TEXTDOMAINDIR" ]
	then
		TEXTDOMAINDIR="@@LOCALEDIR@@"
	else
		TEXTDOMAINDIR="$GIT_TEXTDOMAINDIR"
	fi
	export TEXTDOMAINDIR
else
	# Since gettext.sh isn't available we'll have to define our own
	# dummy pass-through functions.

	gettext () {
		printf "%s" "$1"
	}

	eval_gettext () {
		gettext_eval="printf '%s' \"$1\""
		printf "%s" "`eval \"$gettext_eval\"`"
	}
fi
