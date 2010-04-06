#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description='git commit --allow-empty-message'

. ./test-lib.sh

commit_msg_is () {
	test "`git log --pretty=format:%s%b -1`" = "$1"
}

# A sanity check to see if commit is working at all.
test_expect_success 'a basic commit in an empty tree should succeed' '
	(
		echo content > foo &&
		git add foo &&
		git commit -m "initial commit"
	) &&
	commit_msg_is "initial commit"
'

test_expect_success 'Commit no message with --allow-empty-message' '
	(
		echo "more content" >> foo &&
		git add foo &&
		printf "" | git commit --allow-empty-message
	) &&
	commit_msg_is ""
'

test_expect_success 'Commit a message with --allow-empty-message' '
	(
		echo "even more content" >> foo &&
		git add foo &&
		git commit --allow-empty-message -m"hello there"
	) &&
	commit_msg_is "hello there"
'
test_done
