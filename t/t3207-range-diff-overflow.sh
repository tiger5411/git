#!/bin/sh

test_description='range-diff overflow tests'

. ./test-lib.sh

test_lazy_prereq PRINTF_SUPPORTS_N_EXPANSION '
	printf "ARG_%d\n" $(test_seq 1 50000) >out &&

	cat >expect <<-\EOF
	ARG_1
	ARG_2
	ARG_3
	EOF
	head -n 3 out >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF
	ARG_49998
	ARG_49999
	ARG_50000
	EOF
	tail -n 3 out >actual &&
	test_cmp expect actual
'

if ! test_have_prereq EXPENSIVE
then
	skip_all="set GIT_TEST_LONG=true to run this test"
	test_done
fi



if ! test_have_prereq PRINTF_SUPPORTS_N_EXPANSION
then
	skip_all="this OS's printf(1) + our test_seq can't create our test data"
	test_done
fi

test_expect_success 'setup' '
	test_commit base
'

# For a fast functin test_commit_bulk is quite slow for what it can do
# without test_tick and the like in a loop
test_commit_bulkier () {
	fmt=$(sed 's/Z$//' <<-END_FMT
	commit refs/heads/$1
	author $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL> $GIT_AUTHOR_DATE
	committer $GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL> $GIT_COMMITTER_DATE
	data <<EOF
	EOF
	M 644 inline $2
	data <<EOF
	%d
	EOF
	END_FMT
	) &&
	printf "$fmt\n\n" $(test_seq 1 $3)
}

test_expect_success 'setup: O(i * j) overflow; 46341^2 is a bit over 2^31' '
	test_commit_bulkier A A.txt 46341 >stream &&
	git fast-import <stream &&

	test_commit_bulkier B B.txt 46341 >stream &&
	git fast-import <stream
'

test_expect_success 'O(i * j) "int" overflow' '
	GIT_PROGRESS_DELAY=0 git range-diff --creation-factor=100 --progress base A B
'


test_done
