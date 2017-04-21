#!/bin/sh

test_description="Comparison of git-grep's regex engines"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

for engine in fixed basic extended perl
do
	# These patterns gradully go from matching just a few lines to
	# matching a *lot* in linux.git
	for pattern in \
		'pedantic' \
		'TODO' \
		'bug' \
		'and' \
		'int' \
		' '
	do
		test_perf "$engine with $pattern" "
			git -c grep.patternType=$engine grep -- '$pattern' || :
		"
	done
done

test_done
