#!/bin/sh

git grep -l '\b(eval_gettext|gettext|gettextln|eval_gettextln)\b' -- *.sh \
	| grep -v \
	-e util-remove-i18n.sh \
	-e git-sh-i18n.sh \
	-e helper-i18n-subst-candidates.sh \
	-e util-remove-i18n.sh
