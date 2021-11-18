#!/bin/sh

test_description='tests for the object-array.[ch] API'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit_bulk 1024
'

test_expect_success 'object-array: add objects' '
	git rev-list HEAD >obj &&
	test-tool object-array <obj
'

test_done
