#!/bin/sh
#
# Copyright (c) 2021 Han Xin
#

test_description='Test unpack-objects when receive pack'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success "create commit with big blobs (1.5 MB)" '
	test-tool genrandom foo 1500000 >big-blob &&
	test_commit --append foo big-blob &&
	test-tool genrandom bar 1500000 >big-blob &&
	test_commit --append bar big-blob &&
	(
		cd .git &&
		find objects/?? -type f | sort
	) >expect &&
	PACK=$(echo main | git pack-objects --progress --revs test)
'

test_expect_success 'setup GIT_ALLOC_LIMIT to 1MB' '
	GIT_ALLOC_LIMIT=1m &&
	export GIT_ALLOC_LIMIT
'

test_expect_success 'prepare dest repository' '
	git init --bare dest.git &&
	git -C dest.git config core.bigFileThreshold 2m &&
	git -C dest.git config receive.unpacklimit 100
'

test_expect_success 'fail to unpack-objects: cannot allocate' '
	test_must_fail git -C dest.git unpack-objects <test-$PACK.pack 2>err &&
	test_i18ngrep "fatal: attempting to allocate" err &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	! test_cmp expect actual
'

test_expect_success 'set a lower bigfile threshold' '
	git -C dest.git config core.bigFileThreshold 1m
'

test_expect_success 'unpack big object in stream' '
	git -C dest.git unpack-objects <test-$PACK.pack &&
	git -C dest.git fsck &&
	(
		cd dest.git &&
		find objects/?? -type f | sort
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'setup for unpack-objects dry-run test' '
	git init --bare unpack-test.git
'

test_expect_success 'unpack-objects dry-run' '
	(
		cd unpack-test.git &&
		git unpack-objects -n <../test-$PACK.pack
	) &&
	(
		cd unpack-test.git &&
		find objects/ -type f
	) >actual &&
	test_must_be_empty actual
'

test_done
