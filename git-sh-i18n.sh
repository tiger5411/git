# This shell library is Git's interface to gettext.sh. See po/README
# for usage instructions.
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

# Export the TEXTDOMAIN* data that we need for Git
TEXTDOMAIN=git
export TEXTDOMAIN
if test -z "$GIT_TEXTDOMAINDIR"
then
	TEXTDOMAINDIR="@@LOCALEDIR@@"
else
	TEXTDOMAINDIR="$GIT_TEXTDOMAINDIR"
fi
export TEXTDOMAINDIR

# First decide what scheme to use...
GIT_INTERNAL_GETTEXT_SH_SCHEME=fallthrough
if test -n "@@USE_GETTEXT_SCHEME@@"
then
	GIT_INTERNAL_GETTEXT_SH_SCHEME="@@USE_GETTEXT_SCHEME@@"
elif test -n "$GIT_INTERNAL_GETTEXT_TEST_FALLBACKS"
then
	: no probing necessary
elif type gettext.sh >/dev/null 2>&1
then
	# GNU libintl's gettext.sh
	GIT_INTERNAL_GETTEXT_SH_SCHEME=gettext.sh
elif test "$(gettext -h 2>&1)" = "-h"
then
	# gettext binary exists but no gettext.sh. likely to be a gettext
	# binary on a Solaris or something that is not GNU libintl
	GIT_INTERNAL_GETTEXT_SH_SCHEME=no-gettext.sh
fi
export GIT_INTERNAL_GETTEXT_SH_SCHEME

# ... and then follow that decision.
case "$GIT_INTERNAL_GETTEXT_SH_SCHEME" in
gettext.sh)
	# Use libintl's gettext.sh, or fall back to English if we can't.
	. gettext.sh
	;;
no-gettext.sh)
	# Solaris has a gettext(1) but no eval_gettext(1), but we only
	# use the former.
	;;
*)
	gettext () {
		printf "%s" "$1"
	}
	;;
esac

# Git-specific wrapper functions
gettextln () {
	gettext "$1"
	echo
}

eval_gettext_unsafe () {
	msgid="$1" &&
	shift &&
	eval "msgfmt=\"$msgid\"" &&
	printf "%s" "$msgfmt"
}

eval_gettext_unsafeln () {
	eval_gettext_unsafe "$@"
	echo
}

# Forbid using eval_gettext, requires envsubst(1)
eval_gettext () {
	echo "do not use eval_gettext in git, use gettext(ln)_subst instead" >&2
	return 1
}
