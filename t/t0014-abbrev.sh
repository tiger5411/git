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

test_done
