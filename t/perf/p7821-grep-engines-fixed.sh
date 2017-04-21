#!/bin/sh

test_description="Comparison of git-grep's regex engines"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

for engine in fixed basic extended perl
do
	test_perf "$engine grep int"    "
		git -c grep.patternType=$engine grep int >out.$engine.int || :
	"
	test_perf "$engine grep -i int" "
		git -c grep.patternType=$engine grep -i int >out.$engine.i.int || :
	"
	test_perf "$engine grep æ"      "
		git -c grep.patternType=$engine grep æ >out.$engine.æ || :
	"
	test_perf "$engine grep -i æ"      "
		git -c grep.patternType=$engine grep -i æ >out.$engine.i.æ || :
	"
done

for suffix in int i.int æ i.æ
do  
	test_expect_success "assert that the $suffix patterns found the same things under all engines" "
		test_cmp out.fixed.$suffix out.basic.$suffix &&
		test_cmp out.fixed.$suffix out.extended.$suffix &&
		test_cmp out.fixed.$suffix out.extended.$suffix &&
		test_cmp out.fixed.$suffix out.perl.$suffix
	"
done

test_done
