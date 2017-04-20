#!/bin/sh

test_description="Comparison of git-grep's regex engines"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

# TODO FIXUP
<<<<<<< HEAD
for engine in basic extended pcre1 pcre2
=======
for engine in basic extended perl
>>>>>>> b9196bb3f4... grep: remove support for concurrent use of both PCRE v1 & v2
do
	for pattern in \
		'how.to' \
		'^how to' \
		'[how] to'
	do
		test_perf "$engine with $pattern" "
			git -c grep.patternType=$engine grep -- '$pattern' || :
		"
	done
done

test_done
