#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='Test custom diff function name patterns'

. ./test-lib.sh

test_expect_success 'setup' '
	test-tool userdiff list-builtin-drivers >builtin-drivers &&
	test_file_not_empty builtin-drivers &&
	builtin_drivers=$(cat builtin-drivers) &&

	# for regexp compilation tests
	echo A >A.java &&
	echo B >B.java
'

diffpatterns="
	$builtin_drivers
	custom
"

for p in $diffpatterns
do
	test_expect_success "builtin $p pattern compiles" '
		echo "*.java diff=$p" >.gitattributes &&
		test_expect_code 1 git diff --no-index \
			A.java B.java 2>msg &&
		test_i18ngrep ! fatal msg &&
		test_i18ngrep ! error msg
	'
	test_expect_success "builtin $p wordRegex pattern compiles" '
		echo "*.java diff=$p" >.gitattributes &&
		test_expect_code 1 git diff --no-index --word-diff \
			A.java B.java 2>msg &&
		test_i18ngrep ! fatal msg &&
		test_i18ngrep ! error msg
	'
done

test_expect_success 'last regexp must not be negated' '
	echo "*.java diff=java" >.gitattributes &&
	test_config diff.java.funcname "!static" &&
	test_expect_code 128 git diff --no-index A.java B.java 2>msg &&
	test_i18ngrep ": Last expression must not be negated:" msg
'

do_change_me () {
	file=$1
	sed -e "s/ChangeMe/IWasChanged/" <"$file" >tmp &&
	mv tmp "$file"
}

last_diff_context_line () {
	file=$1
	sed -n -e "s/^.*@@\( \|$\)//p" <$file
}

test_diff_funcname () {
	desc=$1
	cat <&8 >arg.header &&
	cat <&9 >arg.test &&
	what=$(cat arg.what) &&

	test_expect_success "setup: $desc" '
		cp arg.test "$what" &&
		cp arg.header expected &&
		git add "$what" &&
		do_change_me "$what"
	' &&

	test_expect_success "$desc" '
		git diff -U1 "$what" >diff &&
		last_diff_context_line diff >actual &&
		test_cmp expected actual
	'
}

for what in $diffpatterns
do
	test="$TEST_DIRECTORY/t4018/$what.sh"
	if ! test -e "$test"
	then
		test_expect_failure "$what: no tests" 'false'
		continue
	fi &&

	test_expect_success "setup: hunk header for $what" '
		echo "$what diff=$what" >.gitattributes &&
		echo "$what" >arg.what
	' &&

	. "$test"
done

test_done
