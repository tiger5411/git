#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description='Gettext Shell fallbacks'

GIT_INTERNAL_GETTEXT_TEST_FALLBACKS=YesPlease
export GIT_INTERNAL_GETTEXT_TEST_FALLBACKS

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-gettext.sh

test_expect_success "sanity: \$GIT_INTERNAL_GETTEXT_SH_SCHEME is set (to $GIT_INTERNAL_GETTEXT_SH_SCHEME)" '
    test -n "$GIT_INTERNAL_GETTEXT_SH_SCHEME"
'

test_expect_success 'sanity: $GIT_INTERNAL_GETTEXT_TEST_FALLBACKS is set' '
    test -n "$GIT_INTERNAL_GETTEXT_TEST_FALLBACKS"
'

test_expect_success 'sanity: $GIT_INTERNAL_GETTEXT_SH_SCHEME" is fallthrough' '
    echo fallthrough >expect &&
    echo $GIT_INTERNAL_GETTEXT_SH_SCHEME >actual &&
    test_cmp expect actual
'

test_expect_success 'gettext: our gettext() fallback has pass-through semantics' '
    printf "test" >expect &&
    gettext "test" >actual &&
    test_cmp expect actual &&
    printf "test more words" >expect &&
    gettext "test more words" >actual &&
    test_cmp expect actual
'

test_expect_success 'eval_gettext: our eval_gettext() errorsout' '
    ! eval_gettext "test" >actual
'

test_done
