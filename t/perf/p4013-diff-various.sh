#!/bin/sh

test_description="Test diff performance"

. ./perf-lib.sh

test_perf_default_repo

# Not --max-count, as that's the number of matching commit, so it's
# unbounded. We want to limit our revision walk here.
from_rev_desc=
from_rev=
if ! test_have_prereq EXPENSIVE
then
	max_count=500
	from_rev=" $(git rev-list HEAD | head -n $max_count | tail -n 1).."
	from_rev_desc=" <limit-rev>.."
fi

for opts in \
	'-p' \
	'--stat ' \
	'-p --word-diff'
do
	test_perf "git log --format=%H $opts$from_rev_desc" "
		git log --format=%H $opts$from_rev
	"
done

for opts in \
	'-p -U10' \
	'-p --diff-algorithm=myers' \
	'-p --diff-algorithm=minimal' \
	'-p --diff-algorithm=patience' \
	'-p --diff-algorithm=histogram' \
	'-p --patience' \
	'-p --histogram' \
	'--raw' \
	'--numstat ' \
	'--shortstat ' \
	'--dirstat ' \
	'--name-only ' \
	'--name-status ' \
	'-p --word-diff-regex=.' \
	'-p -M5%' \
	'-p -M95%' \
	'-p -w'
do
	test_perf PERF_EXTRA "git log --format=%H $opts$from_rev_desc" "
		git log --format=%H $opts$from_rev
	"
done

test_done
