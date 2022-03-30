#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description='Gettext support for Git'

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-gettext.sh

test_expect_success 'xgettext sanity: Perl _() strings are not extracted' '
    ! grep "A Perl string xgettext will not get" "$GIT_PO_PATH"/is.po
'

test_expect_success 'xgettext sanity: Comment extraction with --add-comments' '
    grep "TRANSLATORS: This is a test" "$TEST_DIRECTORY"/t0200/* | wc -l >expect &&
    grep "TRANSLATORS: This is a test" "$GIT_PO_PATH"/is.po  | wc -l >actual &&
    test_cmp expect actual
'

test_expect_success 'xgettext sanity: Comment extraction with --add-comments stops at statements' '
    ! grep "This is a phony" "$GIT_PO_PATH"/is.po &&
    ! grep "the above comment" "$GIT_PO_PATH"/is.po
'


test_expect_success GETTEXT 'sanity: Icelandic locale was compiled' '
    test -f "$GIT_TEXTDOMAINDIR/is/LC_MESSAGES/git.mo"
'

test_expect_success GETTEXT_LOCALE 'sanity: gettext(unknown) is passed through' '
    printf "This is not a translation string"  >expect &&
    gettext "This is not a translation string" >actual &&
    test_cmp expect actual
'

test_expect_success GETTEXT_LOCALE 'sanity: eval_gettext(unknown) is an error' '
    ! eval_gettext "This is not a translation string"
'

gettext () {
	git sh-i18n--helper "$1"
}

# xgettext from C
test_expect_success GETTEXT_LOCALE 'xgettext: C extraction of _() and N_() strings' '
    printf "TILRAUN: C tilraunastrengur" >expect &&
    printf "\n" >>expect &&
    printf "Sjá '\''git help SKIPUN'\'' til að sjá hjálp fyrir tiltekna skipun." >>expect &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "TEST: A C test string" >actual &&
    printf "\n" >>actual &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "See '\''git help COMMAND'\'' for more information on a specific command." >>actual &&
    test_cmp expect actual
'

test_expect_success GETTEXT_LOCALE 'xgettext: C extraction with %s' '
    printf "TILRAUN: C tilraunastrengur %%s" >expect &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "TEST: A C test string %s" >actual &&
    test_cmp expect actual
'

# xgettext from Shell
test_expect_success GETTEXT_LOCALE 'xgettext: Shell extraction' '
    printf "TILRAUN: Skeljartilraunastrengur" >expect &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "TEST: A Shell test string" >actual &&
    test_cmp expect actual
'

# xgettext from Perl
test_expect_success GETTEXT_LOCALE 'xgettext: Perl extraction' '
    printf "TILRAUN: Perl tilraunastrengur" >expect &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "TEST: A Perl test string" >actual &&
    test_cmp expect actual
'

test_expect_success GETTEXT_LOCALE 'xgettext: Perl extraction with %s' '
    printf "TILRAUN: Perl tilraunastrengur með breytunni %%s" >expect &&
    LANGUAGE=is LC_ALL="$is_IS_locale" gettext "TEST: A Perl test variable %s" >actual &&
    test_cmp expect actual
'

test_done
