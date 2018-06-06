#!/bin/sh

test_description='test core.abbrev and related features'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit A
'

test_expect_success 'the FALLBACK_DEFAULT_ABBREV is 7' '
	git log -1 --pretty=format:%h >log &&
	test_byte_count = 7 log
'

test_expect_success 'core.abbrev empty values error out' '
	test_must_fail git -c core.abbrev= log -1 --pretty=format:%h 2>stderr &&
	test_i18ngrep "bad numeric config value.*invalid unit" stderr
'

test_expect_success '--abbrev empty values fall back on MINIMUM_ABBREV' '
	git log --abbrev= -1 --pretty=format:%h >log &&
	test_byte_count = 4 log
'

for i in -41 -20 -10 -1 0 1 2 3 41
do
	test_expect_success "core.abbrev value $i out of range errors out" "
		test_must_fail git -c core.abbrev=$i log -1 --pretty=format:%h 2>stderr &&
		test_i18ngrep 'abbrev length out of range' stderr
	"
done

for i in -41 -20 -10 -1
do
	test_expect_success "negative --abbrev=$i value out of range means --abbrev=40" "
		git log --abbrev=$i -1 --pretty=format:%h >log &&
		test_byte_count = 40 log
	"
done

for i in 0 1 2 3 4
do
	test_expect_success "non-negative --abbrev=$i value <MINIMUM_ABBREV falls back on MINIMUM_ABBREV" "
		git log --abbrev=$i -1 --pretty=format:%h >log &&
		test_byte_count = 4 log
	"
done

for i in 41 9001
do
	test_expect_success "non-negative --abbrev=$i value >MINIMUM_ABBREV falls back on 40" "
		git log --abbrev=$i -1 --pretty=format:%h >log &&
		test_byte_count = 40 log
	"
done

for i in $(test_seq 4 40)
do
	test_expect_success "core.abbrev=$i and --abbrev=$i in combination within the valid range" "
		# Both core.abbrev=X and --abbrev=X do the same thing
		# in isolation
		git -c core.abbrev=$i log -1 --pretty=format:%h >log &&
		test_byte_count = $i log &&
		git log --abbrev=$i -1 --pretty=format:%h >log &&
		test_byte_count = $i log &&

		# The --abbrev option should take priority over
		# core.abbrev
		git -c core.abbrev=20 log --abbrev=$i -1 --pretty=format:%h >log &&
		test_byte_count = $i log
	"
done

tr_d_n() {
	tr -d '\n'
}

cut_tr_d_n_field_n() {
    cut -d " " -f $1 | tr_d_n
}

for i in $(test_seq 4 40)
do
	test_expect_success "blame core.abbrev=$i and --abbrev=$i" "
		# See the blame documentation for why this is off-by-one
		git -c core.abbrev=$i blame A.t | cut_tr_d_n_field_n 1 >blame &&
		test_byte_count = \$(($i + 1)) blame &&
		git blame --abbrev=$i A.t | cut_tr_d_n_field_n 1 >blame &&
		# This is a bug in blame --abbrev
		if test $i -eq 40
		then
			test_byte_count = $i blame
		else
			test_byte_count = \$(($i + 1)) blame
		fi
	"
done

for i in $(test_seq 4 40)
do
	test_expect_success "branch core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i branch -v | cut_tr_d_n_field_n 3 >branch &&
		test_byte_count = $i branch &&
		git branch --abbrev=$i -v | cut_tr_d_n_field_n 3 >branch &&
		test_byte_count = $i branch
	"
done

test_expect_success 'describe setup' '
	git tag -a -mannotated A.annotated &&
	test_commit B
'

test_expect_success 'describe core.abbrev and --abbrev special cases' '
	# core.abbrev=0 behaves as usual...
	test_must_fail git -c core.abbrev=0 describe &&

	# ...but --abbrev=0 is special-cased to print the nearest tag,
	# not fall back on "4" like git-log.
	echo A.annotated >expected &&
	git describe --abbrev=0 >actual &&
	test_cmp expected actual
'

sed_g_tr_n() {
	sed 's/.*g//' | tr_d_n
}

for i in $(test_seq 4 40)
do
	test_expect_success "describe core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i describe | sed_g_tr_n >describe &&
		test_byte_count = $i describe &&
		git describe --abbrev=$i | sed_g_tr_n >describe &&
		test_byte_count = $i describe
	"
done

for i in $(test_seq 4 40)
do
	test_expect_success "ls-files core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i ls-files --stage A.t | cut_tr_d_n_field_n 2 >ls-files &&
		test_byte_count = 40 ls-files &&
		git ls-files --abbrev=$i --stage A.t | cut_tr_d_n_field_n 2 >ls-files &&
		test_byte_count = $i ls-files
	"
done

for i in $(test_seq 4 40)
do
	test_expect_success "ls-tree core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i ls-tree HEAD A.t | cut -f 1 | cut_tr_d_n_field_n 3 >ls-tree &&
		test_byte_count = 40 ls-tree &&
		git ls-tree --abbrev=$i HEAD A.t | cut -f 1 | cut_tr_d_n_field_n 3 >ls-tree &&
		test_byte_count = $i ls-tree
	"
done

for i in $(test_seq 4 40)
do
	test_expect_success "show-ref core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i show-ref --hash refs/heads/master | tr_d_n >show-ref &&
		test_byte_count = 40 show-ref &&
		git show-ref --hash --abbrev=$i refs/heads/master | tr_d_n >show-ref &&
		test_byte_count = $i show-ref &&
		git show-ref --hash=$i refs/heads/master | tr_d_n >show-ref &&
		test_byte_count = $i show-ref
	"
done

test_done
