# This shell library is Git's interface to gettext.sh. See po/README
# for usage instructions.
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

gettext () {
	git sh-i18n--helper "$1"
}

# Git-specific wrapper functions
gettextln () {
	gettext "$1"
	echo
}

eval_gettext_unsafe () {
	eval "msgfmt=\"$1\"" &&
	printf "%s" "$1"
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
