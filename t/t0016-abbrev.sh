#!/bin/sh

test_description='test core.abbrev and related features'

. ./test-lib.sh

tr_d_n() {
	tr -d '\n'
}

cut_tr_d_n_field_n() {
	cut -d " " -f $1 | tr_d_n
}

nocaret() {
	sed 's/\^//'
}

sed_g_tr_d_n() {
	sed 's/.*g//' | tr_d_n
}

test_expect_success 'setup' '
	test_commit A &&
	git tag -a -mannotated A.annotated &&
	test_commit B &&
	test_commit C &&
	mkdir X Y &&
	touch X/file1 Y/file2
'

test_expect_success 'the FALLBACK_DEFAULT_ABBREV is 7' '
	git log -1 --pretty=format:%h >log &&
	test_byte_count = 7 log
'

test_expect_success 'abbrev empty value handling differs ' '
	test_must_fail git -c core.abbrev= log -1 --pretty=format:%h 2>stderr &&
	test_i18ngrep "bad numeric config value.*invalid unit" stderr &&

	git branch -v --abbrev= | cut_tr_d_n_field_n 3 >branch &&
	test_byte_count = 40 branch &&

	git log --abbrev= -1 --pretty=format:%h >log &&
	test_byte_count = 4 log &&

	git diff --raw --abbrev= HEAD~ >diff &&
	cut_tr_d_n_field_n 3 <diff >diff.3 &&
	test_byte_count = 4 diff.3 &&
	cut_tr_d_n_field_n 4 <diff >diff.4 &&
	test_byte_count = 4 diff.4 &&

	test_must_fail git diff --raw --abbrev= --no-index X Y >diff &&
	cut_tr_d_n_field_n 3 <diff >diff.3 &&
	test_byte_count = 40 diff.3 &&
	cut_tr_d_n_field_n 4 <diff >diff.4 &&
	test_byte_count = 40 diff.4
'

test_expect_success 'abbrev non-integer value handling differs ' '
	test_must_fail git -c core.abbrev=XYZ log -1 --pretty=format:%h 2>stderr &&
	test_i18ngrep "bad numeric config value.*invalid unit" stderr &&

	test_must_fail git branch -v --abbrev=XYZ 2>stderr &&
	test_i18ngrep "expects a numerical value" stderr &&

	git log --abbrev=XYZ -1 --pretty=format:%h 2>stderr &&
	! test -s stderr &&

	git diff --raw --abbrev=XYZ HEAD~ 2>stderr &&
	! test -s stderr &&

	test_must_fail git diff --raw --abbrev=XYZ --no-index X Y 2>stderr &&
	test_i18ngrep "expects a numerical value" stderr
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

for i in $(test_seq 4 40)
do
	for opt in --porcelain --line-porcelain
	do
		test_expect_success "blame $opt ignores core.abbrev=$i and --abbrev=$i" "
			git -c core.abbrev=$i blame $opt A.t | head -n 1 | cut_tr_d_n_field_n 1 >blame &&
			test_byte_count = 40 blame &&
			git blame $opt --abbrev=$i A.t | head -n 1 | cut_tr_d_n_field_n 1 >blame &&
			test_byte_count = 40 blame
		"
	done


	test_expect_success "blame core.abbrev=$i and --abbrev=$i with boundary" "
		# See the blame documentation for why this is off-by-one
		git -c core.abbrev=$i blame A.t | cut_tr_d_n_field_n 1 | nocaret >blame &&
		if test $i -eq 40
		then
			test_byte_count = 39 blame
		else
			test_byte_count = $i blame
		fi &&
		git blame --abbrev=$i A.t | cut_tr_d_n_field_n 1 | nocaret >blame &&
		if test $i -eq 40
		then
			test_byte_count = 39 blame
		else
			test_byte_count = $i blame
		fi
	"

	test_expect_success "blame core.abbrev=$i and --abbrev=$i without boundary" "
		git -c core.abbrev=$i blame B.t | cut_tr_d_n_field_n 1 | nocaret >blame &&
		if test $i -eq 40
		then
			test_byte_count = $i blame
		else
			test_byte_count = \$(($i + 1)) blame
		fi &&
		git blame --abbrev=$i B.t | cut_tr_d_n_field_n 1 | nocaret >blame &&
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

test_expect_success 'describe core.abbrev and --abbrev special cases' '
	# core.abbrev=0 behaves as usual...
	test_must_fail git -c core.abbrev=0 describe &&

	# ...but --abbrev=0 is special-cased to print the nearest tag,
	# not fall back on "4" like git-log.
	echo A.annotated >expected &&
	git describe --abbrev=0 >actual &&
	test_cmp expected actual
'

for i in $(test_seq 4 40)
do
	test_expect_success "describe core.abbrev=$i and --abbrev=$i" "
		git -c core.abbrev=$i describe | sed_g_tr_d_n >describe &&
		test_byte_count = $i describe &&
		git describe --abbrev=$i | sed_g_tr_d_n >describe &&
		test_byte_count = $i describe
	"
done

test_done
