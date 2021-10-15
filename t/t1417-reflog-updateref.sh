#!/bin/sh

test_description='git reflog --updateref'

. ./test-lib.sh


test_expect_success 'reflog --updateref' '
	git init updateref &&
	(
		cd updateref &&
		test_commit A &&
		test_commit B &&
		test_commit C &&
		git reflog
	) &&
	false
'

test_done
