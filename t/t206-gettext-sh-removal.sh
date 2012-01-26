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

test_expect_success 'gettext: interpolation invocation' '
    cat >test <<-\EOF &&
    die "$(gettext "You need to set your committer info first")"
EOF
    cat >expected <<-\EOF &&
    die "You need to set your committer info first"
EOF
    $GIT_BUILD_DIR/util-remove-i18n.sh <test >actual
   test_cmp expected actual
'

test_expect_success 'gettextln: basic invocation' '
    cat >test <<-\EOF &&
    gettextln "Cannot fall back to three-way merge."
    gettextln "Warning: bisecting only with a bad commit." >&2
EOF
    cat >expected <<-\EOF &&
    echo "Cannot fall back to three-way merge."
    echo "Warning: bisecting only with a bad commit." >&2
EOF
    $GIT_BUILD_DIR/util-remove-i18n.sh <test >actual
   test_cmp expected actual
'

test_expect_success 'gettext: one line, with variable substitution' "
    cat >test <<-\EOF &&
    die \"\$(eval_gettext \"Failed to recurse into submodule path '\\\$path'\")\"
EOF
    cat >expected <<-\EOF &&
    die \"Failed to recurse into submodule path '\$path'\"
EOF
    \$GIT_BUILD_DIR/util-remove-i18n.sh <test >actual
   test_cmp expected actual
"

test_done
