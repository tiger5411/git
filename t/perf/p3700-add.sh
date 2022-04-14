#!/bin/sh
#
# This test measures the performance of adding new files to the object database
# and index. The test was originally added to measure the effect of the
# core.fsyncMethod=batch mode, which is why we are testing different values
# of that setting explicitly and creating a lot of unique objects.

test_description="Tests performance of adding things to the object database"

# Fsync is normally turned off for the test suite.
GIT_TEST_FSYNC=1
export GIT_TEST_FSYNC

. ./perf-lib.sh

test_perf_default_repo
test_checkout_worktree

for cfg in \
	'-c core.fsync=-loose-object -c core.fsyncmethod=fsync' \
	'-c core.fsync=loose-object -c core.fsyncmethod=fsync' \
	'-c core.fsync=loose-object -c core.fsyncmethod=batch' \
	'-c core.fsyncmethod=batch'
do
	test_perf "'git add' with '$cfg'" \
		--setup '
			mv -v .git .git.old &&
			git init .
		' \
		--cleanup '
			rm -rf .git &&
			mv .git.old .git
		' '
		git $cfg add -f -- ":!.git.old/"
	'
done

test_done
