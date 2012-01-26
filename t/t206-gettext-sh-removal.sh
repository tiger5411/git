#!/bin/sh
#
# Copyright (c) 2012 Ævar Arnfjörð Bjarmason and Eric Herman
#

test_description='Gettext Shell poison'

. ./test-lib.sh

remove_script=$GIT_BUILD_DIR/util-remove-i18n.sh

test_expect_success 'gettext: basic invocation' '
    cat >test <<-\EOF &&
    die "$(gettext "You need to set your committer info first")"
EOF
    cat >expected <<-\EOF &&
    die "You need to set your committer info first"
EOF
    $GIT_BUILD_DIR/util-remove-i18n.sh <test >actual
   test_cmp expected actual
'

test_done
