#!/bin/sh

test_description='tests for the object-list.[ch] API'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit_bulk 1024
'

test_expect_success 'object-list: add objects' '
	git rev-list HEAD >obj &&
	test-tool object-list <obj
'

test_done
