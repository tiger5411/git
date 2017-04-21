#!/bin/sh

test_description="Comparison of git-grep's regex engines with -F

Set GIT_PERF_7821_GREP_OPTS in the environment to pass options to
git-grep. Make sure to include a leading space,
e.g. GIT_PERF_7821_GREP_OPTS=' -w'. See p7820-grep-engines.sh for more
options to try.
"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

for args in 'int' 'uncommon' 'æ'
do
	for engine in fixed basic extended perl
	do
		test_perf "$engine grep$GIT_PERF_7821_GREP_OPTS $args" "
			git -c grep.patternType=$engine grep$GIT_PERF_7821_GREP_OPTS $args >'out.$engine.$args' || :
		"
	done

	test_expect_success "assert that all engines found the same for$GIT_PERF_7821_GREP_OPTS $args" "
		test_cmp 'out.fixed.$args' 'out.basic.$args' &&
		test_cmp 'out.fixed.$args' 'out.extended.$args' &&
		test_cmp 'out.fixed.$args' 'out.perl.$args'
	"
done

test_done
