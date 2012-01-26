#!/bin/sh
#
# Copyright (c) 2012 Ævar Arnfjörð Bjarmason and Eric Herman
#

test_description='Gettext Shell poison'

. ./test-lib.sh

remove_script=$GIT_BUILD_DIR/util-remove-i18n.sh

test_expect_success 'gettext: basic invocation' '
    cat >test <<-\EOF &&
    gettext "Apply? [y]es/[n]o/[e]dit/[v]iew patch/[a]ccept all "
    gettext "Do you want me to do it for you [Y/n]? " >&2
EOF
    cat >expected <<-\EOF &&
    printf "%s" "Apply? [y]es/[n]o/[e]dit/[v]iew patch/[a]ccept all "
    printf "%s" "Do you want me to do it for you [Y/n]? " >&2
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
    die \"\$(eval_gettext \"No submodule mapping found in .gitmodules for path '\\\$path'\")\"
    die \"\$(eval_gettext \"Clone of '\\\$url' into submodule path '\\\$path' failed\")\"
    die \"\$(eval_gettext \"repo URL: '\\\$repo' must be absolute or begin with ./|../\")\"
EOF
    cat >expected <<-\EOF &&
    die \"Failed to recurse into submodule path '\$path'\"
    die \"No submodule mapping found in .gitmodules for path '\$path'\"
    die \"Clone of '\$url' into submodule path '\$path' failed\"
    die \"repo URL: '\$repo' must be absolute or begin with ./|../\"
EOF
    \$GIT_BUILD_DIR/util-remove-i18n.sh <test >actual
   test_cmp expected actual
"

test_done
