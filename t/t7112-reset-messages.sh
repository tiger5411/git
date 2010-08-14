#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description='git reset warning and error messages'

. ./test-lib.sh

test_expect_success 'setup {err,out}-expect' "
	cat >err-expect <<EOF &&
warning: --mixed with paths is deprecated; use 'git reset -- <paths>' instead.
EOF
	cat >out-expect <<EOF
Unstaged changes after reset:
M	hlagh
EOF
"

test_expect_success 'git reset --mixed <paths> warning' '
	# Not test_commit() due to "ambiguous argument [..] both revision
	# and filename"
	echo stuff >hlagh &&
	git add hlagh &&
	git commit -m"adding stuff" hlagh &&
	echo more stuff >hlagh &&
	git add hlagh &&
	test_must_fail git reset --mixed hlagh >out 2>err &&
	test_cmp err-expect err &&
	test_cmp out-expect out
'

test_done
