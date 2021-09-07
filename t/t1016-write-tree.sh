#!/bin/sh

test_description='git write-tree'

. ./test-lib.sh

test_expect_success 'usage' '
	test_expect_code 129 git write-tree no-subcommand
'

test_done
