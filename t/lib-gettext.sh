#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

. ./test-lib.sh

GIT_TEXTDOMAINDIR="$GIT_BUILD_DIR/share/locale"
GIT_PO_PATH="$GIT_BUILD_DIR/po"
export GIT_TEXTDOMAINDIR GIT_PO_PATH

. "$GIT_BUILD_DIR"/git-sh-i18n

if test_have_prereq GETTEXT && test_have_prereq NO_GETTEXT_POISON
then
	# is_IS.UTF-8 on Solaris and FreeBSD, is_IS.utf8 on Debian
	is_IS_locale=$(locale -a | sed -n '/^is_IS\.[uU][tT][fF]-*8$/{
		p
		q
	}')
	# is_IS.ISO8859-1 on Solaris and FreeBSD, is_IS.iso88591 on Debian
	is_IS_iso_locale=$(locale -a | sed -n '/^is_IS\.[iI][sS][oO]8859-*1$/{
		p
		q
	}')

	# Export them as an environmental variable so the t0202/test.pl
	# Perl test can use it too
	export is_IS_locale is_IS_iso_locale

	if test -n "$is_IS_locale" &&
		test $GIT_INTERNAL_GETTEXT_SH_SCHEME != "fallthrough"
	then
		# Some of the tests need the reference Icelandic locale
		test_set_prereq GETTEXT_LOCALE

		# Exporting for t0202/test.pl
		GETTEXT_LOCALE=1
		export GETTEXT_LOCALE
		say "# lib-gettext: Found '$is_IS_locale' as a is_IS UTF-8 locale"
	else
		say "# lib-gettext: No is_IS UTF-8 locale available"
	fi

	if test -n "$is_IS_iso_locale" &&
		test $GIT_INTERNAL_GETTEXT_SH_SCHEME != "fallthrough"
	then
		# Some of the tests need the reference Icelandic locale
		test_set_prereq GETTEXT_ISO_LOCALE

		# Exporting for t0202/test.pl
		GETTEXT_ISO_LOCALE=1
		export GETTEXT_ISO_LOCALE
		say "# lib-gettext: Found '$is_IS_iso_locale' as a is_IS ISO-8859-1 locale"
	else
		say "# lib-gettext: No is_IS ISO-8859-1 locale available"
	fi
else
	# Only run some tests when we don't have gettext support
	test_set_prereq NO_GETTEXT

	if test_have_prereq NO_GETTEXT_POISON
	then
		say "# lib-gettext: GETTEXT_POISON defined, can't test gettext"
	else
		say "# lib-gettext: No GETTEXT support available"
	fi
fi

test_eval_gettext_interpolation() {
	test_expect_success NO_GETTEXT_POISON 'eval_gettext: our eval_gettext() fallback can interpolate whitespace variables' '
	    git_am_cmdline="git am" &&
	    printf "test git am" >expect &&
	    eval_gettext "test \$git_am_cmdline" >actual &&
	    test_cmp expect actual
	'

	test_expect_success NO_GETTEXT_POISON 'eval_gettext: git am $cmdline bug' '
	    cmdline="git am -3" &&
	    export cmdline &&
	    cat >expect <<EOF &&
When you have resolved this problem run "git am -3 --resolved".
If you would prefer to skip this patch, instead run "git am -3 --skip".
To restore the original branch and stop patching run "git am -3 --abort".
EOF
	    eval_gettext "When you have resolved this problem run \"\$cmdline --resolved\".
If you would prefer to skip this patch, instead run \"\$cmdline --skip\".
To restore the original branch and stop patching run \"\$cmdline --abort\"." >actual &&
	    echo >>actual &&
	    test_cmp expect actual
	'
}
