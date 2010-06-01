#!/bin/sh
D=`pwd`
GIT_TEXTDOMAINDIR="$D/../share/locale"
export GIT_TEXTDOMAINDIR

test_description='Gettext support for Git'
. ./test-lib.sh
. ../../git-sh-setup

test_expect_success 'sanity: $TEXTDOMAIN is git' '
    test $TEXTDOMAIN = "git"
'

test_expect_success 'sanity: $TEXTDOMAINDIR exists' '
    test -d "$TEXTDOMAINDIR" &&
    test "$TEXTDOMAINDIR" = "$GIT_TEXTDOMAINDIR"
'

test_expect_success 'sanity: Icelandic locale was compiled' '
    test -f "$TEXTDOMAINDIR/is/LC_MESSAGES/git.mo"
'

test_expect_success 'sanity: No gettext("") data for fantasy locale' '
    LANGUAGE=is LC_ALL=tlh_TLH.UTF-8 gettext "" > real-locale &&
    test_expect_failure test -s real-locale
'

test_expect_success 'sanity: Some gettext("") data for real locale' '
    LANGUAGE=is LC_ALL=is_IS.UTF-8 gettext "" > fantasy-locale &&
    test -s fantasy-locale
'

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
    test_cmp expect actual
'

test_expect_success 'sanity: C program git-status reads our message catalog ' '
    > foo &&
    test_commit "some-file" &&
    git checkout -b topic/gettext-testing &&
    git status | grep topic/gettext-testing > expect &&
    echo "# On branch topic/gettext-testing" > actual &&
    test_cmp expect actual &&

    LANGUAGE=is LC_ALL=is_IS.UTF-8 git status | grep topic/gettext-testing > expect &&
    echo "# Á greininni topic/gettext-testing" > actual &&
    test_cmp expect actual
'

test_expect_success 'sanity: Perl program Git::I18N reads our message catalog ' '
    echo "On branch " > expect &&
    perl -I"$D/../perl" -MGit::I18N -le "print gettext(q[On branch ])" > actual &&
    test_cmp expect actual &&

    echo "Á greininni " > expect &&
    LANGUAGE=is LC_ALL=is_IS.UTF-8 perl -I"$D/../perl" -MGit::I18N -le "print gettext(q[On branch ])" > actual &&
    test_cmp expect actual
'

test_expect_success 'Setup another Git repository for testing' '
    mkdir parent &&
    (cd parent && git init &&
     echo one >file && git add file &&
     git commit -m one)
'

test_expect_success 'sanity: Shell program git-pull reads our message catalog' '
    cd parent &&
    (git pull --tags "../" >out 2>err || :) &&
    grep "Fetching tags only" err &&
    (LANGUAGE=is LC_ALL=is_IS.UTF-8 git pull --tags ../ >out 2>err || :) &&
    grep "Næ aðeins í" err 
'

test_done
