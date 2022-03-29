#!/bin/sh

test_description='performance of "git stash" with different fsync settings'

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
	test_perf "'stash push -u' with '$cfg'" \
		--setup '
			mv -v .git .git.old &&
			git init . &&
			test_commit dummy
		' \
		--cleanup '
			rm -rf .git &&
			mv .git.old .git
		' '
		git $cfg stash push -a -u ":!.git.old/" ":!test*" "."
	'
done

test_done
