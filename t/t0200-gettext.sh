#!/bin/sh

test_description='Gettext support for Git'

. ./test-lib.sh

GIT_TEXTDOMAINDIR="$GIT_EXEC_PATH/share/locale"
GIT_PO_PATH="$GIT_EXEC_PATH/po"
export GIT_TEXTDOMAINDIR GIT_PO_PATH

. "$GIT_EXEC_PATH"/git-sh-i18n

test_expect_success 'sanity: $TEXTDOMAIN is git' '
    test $TEXTDOMAIN = "git"
'

if test_have_prereq GETTEXT; then
	test_expect_success 'sanity: $TEXTDOMAINDIR exists without NO_GETTEXT=YesPlease' '
    test -d "$TEXTDOMAINDIR" &&
    test "$TEXTDOMAINDIR" = "$GIT_TEXTDOMAINDIR"
'

	test_expect_success 'sanity: Icelandic locale was compiled' '
    test -f "$TEXTDOMAINDIR/is/LC_MESSAGES/git.mo"
'
else
	test_expect_success "sanity: \$TEXTDOMAINDIR doesn't exists with NO_GETTEXT=YesPlease" '
    test_expect_failure test -d "$TEXTDOMAINDIR" &&
    test "$TEXTDOMAINDIR" = "$GIT_TEXTDOMAINDIR"
'
fi

# Basic xgettext() extraction tests on po/*.po. Doesn't need gettext support
test_expect_success 'xgettext: Perl _() strings are not extracted' '
    test_expect_failure grep "A Perl string xgettext will not get" "$GIT_PO_PATH"/is.po
'

test_expect_success 'xgettext: Comment extraction with --add-comments' '
    grep "TRANSLATORS: This is a test" "$TEST_DIRECTORY"/t0200/* | wc -l > expect &&
    grep "TRANSLATORS: This is a test" "$GIT_PO_PATH"/is.po  | wc -l > actual &&
    test_cmp expect actual
'

test_expect_success 'xgettext: Comment extraction with --add-comments stops at statements' '
    test_expect_failure grep "This is a phony" "$GIT_PO_PATH"/is.po &&
    test_expect_failure grep "the above comment" "$GIT_PO_PATH"/is.po
'

# We can go no further without actual gettext support
if ! test_have_prereq GETTEXT; then
	say "Skipping the rest of the gettext tests, Git was compiled with NO_GETTEXT=YesPlease"
	test_done
fi

test_expect_success 'sanity: No gettext("") data for fantasy locale' '
    LANGUAGE=is LC_ALL=tlh_TLH.UTF-8 gettext "" > real-locale &&
    test_expect_failure test -s real-locale
'

test_expect_success 'sanity: Some gettext("") data for real locale' '
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "" > fantasy-locale &&
    test -s fantasy-locale
'

# TODO: When we have more locales, generalize this to test them
# all. Maybe we'll need a dir->locale map for that.
test_expect_success 'sanity: gettext("") metadata is OK' '
    # Return value may be non-zero
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "" > zero-expect &&
    grep "Project-Id-Version: Git" zero-expect &&
    grep "Git Mailing List <git@vger.kernel.org>" zero-expect &&
    grep "Content-Type: text/plain; charset=UTF-8" zero-expect &&
    grep "Content-Transfer-Encoding: 8bit" zero-expect
'

test_expect_success 'sanity: gettext(unknown) is passed through' '
    printf "This is not a translation string"  > expect &&
    gettext "This is not a translation string" > actual &&
    eval_gettext "This is not a translation string" > actual &&
    test_cmp expect actual
'

# xgettext from C
test_expect_success 'xgettext: C extraction' '
    printf "TILRAUN: C tilraunastrengur" > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "TEST: A C test string" > actual &&
    test_cmp expect actual
'

test_expect_success 'xgettext: C extraction with %s' '
    printf "TILRAUN: C tilraunastrengur %%s" > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "TEST: A C test string %s" > actual &&
    test_cmp expect actual
'

# xgettext from Shell
test_expect_success 'xgettext: Shell extraction' '
    printf "TILRAUN: Skeljartilraunastrengur" > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "TEST: A Shell test string" > actual &&
    test_cmp expect actual
'

test_expect_success 'xgettext: Shell extraction with $variable' '
    printf "TILRAUN: Skeljartilraunastrengur með breytunni a var i able" > x-expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 variable="a var i able" eval_gettext "TEST: A Shell test \$variable" > x-actual &&
    test_cmp x-expect x-actual
'

# xgettext from Perl
test_expect_success 'xgettext: Perl extraction' '
    printf "TILRAUN: Perl tilraunastrengur" > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "TEST: A Perl test string" > actual &&
    test_cmp expect actual
'

test_expect_success 'xgettext: Perl extraction with %s' '
    printf "TILRAUN: Perl tilraunastrengur með breytunni %%s" > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "TEST: A Perl test variable %s" > actual &&
    test_cmp expect actual
'

# Actually execute some C and Shell code that uses Gettext
test_expect_success 'C: git-status reads our message catalog ' '
    test_commit "some-file" &&
    git checkout -b test/gettext &&
    LANGUAGE=C LC_ALL=C git status | grep test/gettext > expect &&
    echo "# On branch test/gettext" > actual &&
    test_cmp expect actual &&

    LANGUAGE=is LC_ALL=is_IS.UTF-8 git status | grep test/gettext > expect &&
    echo "# Á greininni test/gettext" > actual &&
    test_cmp expect actual
'

test_expect_success 'Shell: git-pull reads our message catalog' '
    # Repository for testing
    mkdir parent &&
    (cd parent && git init &&
     echo one >file && git add file &&
     git commit -m one) &&

    # Actual test
    (cd parent &&
    (LANGUAGE=C LC_ALL=C git pull --tags "../" >out 2>err);
    grep "Fetching tags only" err &&
    (LANGUAGE=is LC_ALL=is_IS.UTF-8 git pull --tags ../ >out 2>err || :) &&
    grep "Næ aðeins í" err)
'

test_done
