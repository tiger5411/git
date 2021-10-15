#!/bin/sh

test_description='git reflog --updateref'

. ./test-lib.sh


test_expect_success 'reflog --updateref' '
	git init repo &&
	(
		cd repo &&
		git checkout -b branch &&
		test_commit A &&
		test_commit B &&
		test_commit C &&
		git rev-parse HEAD >../orig.HEAD &&
		git log -g --format="%gs" >../orig.gs
	) &&
	cp -R repo one &&
	git -C one reflog delete 

'

test_done
