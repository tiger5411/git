#!/bin/sh

test_description='git show-index'

. ./test-lib.sh

test_expect_success 'usage' '
	test_expect_code 129 git show-index no-subcommand
'

test_done
