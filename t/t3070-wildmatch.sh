#!/bin/sh

test_description='wildmatch tests'

. ./test-lib.sh

should_create_test_file() {
	file=$1

	case $file in
	# `touch .` will succeed but obviously not do what we intend
	# here.
	".")
		return 1
		;;
	# We cannot create a file with an empty filename.
	"")
		return 1
		;;
	# The tests that are testing that e.g. foo//bar is matched by
	# foo/*/bar can't be tested on filesystems since there's no
	# way we're getting a double slash.
	*//*)
		return 1
		;;
	# When testing the difference between foo/bar and foo/bar/ we
	# can't test the latter.
	*/)
		return 1
		;;
	# On Windows, \ in paths is silently converted to /, which
	# would result in the "touch" below working, but the test
	# itself failing. See 6fd1106aa4 ("t3700: Skip a test with
	# backslashes in pathspec", 2009-03-13) for prior art and
	# details.
	*\\*)
		if ! test_have_prereq BSLASHPSPEC
		then
			return 1
		fi
		# NOTE: The ;;& bash extension is not portable, so
		# this test needs to be at the end of the pattern
		# list.
		#
		# If we want to add more conditional returns we either
		# need a new case statement, or turn this whole thing
		# into a series of "if" tests.
		;;
	esac

	if test_have_prereq MINGW
	then
		case $file in
		" ")
			# Files called " " are forbidden on Windows
			return 1
			;;
		*\**|*\[*)
			return 1
			;;
		esac
	fi

	return 0
}

wildtest_test_function() {
	text=$1
	pattern=$2
	match_expect=$3
	match_function=$4

	# $1: Case sensitive glob match: test-wildmatch
	if test "$match_expect" = 1
	then
		test_expect_success "$match_function: match '$text' '$pattern'" "
			test-wildmatch $match_function '$text' '$pattern'
		"
	elif test "$match_expect" = 0
	then
		test_expect_success "$match_function: no match '$text' '$pattern'" "
			test_must_fail test-wildmatch $match_function '$text' '$pattern'
		"
	else
		test_expect_success "PANIC: Test framework error. Unknown matches value $match_expect" 'false'
	fi

}

wildtest_test_ls_files() {
	text=$1
	pattern=$2
	match_expect=$3
	match_function=$4
	ls_files_args=$5

	wildtest_test_stdout_stderr_cmp="
		tr -d '\0' <actual.raw >actual &&
		>expect.err &&
		test_cmp expect.err actual.err &&
		test_cmp expect actual"

	if test "$match_expect" = 'E'
	then
		if test -e .git/created_test_file
		then
			test_expect_success "$match_function (via ls-files): match dies on '$pattern' '$text'" "
				printf '%s' '$text' >expect &&
				test_must_fail git$ls_files_args ls-files -z -- '$pattern'
			"
		else
			test_expect_failure "$match_function (via ls-files): match skip '$pattern' '$text'" 'false'
		fi
	elif test "$match_expect" = 1
	then
		if test -e .git/created_test_file
		then
			test_expect_success "$match_function (via ls-files): match '$pattern' '$text'" "
				printf '%s' '$text' >expect &&
				git$ls_files_args ls-files -z -- '$pattern' >actual.raw 2>actual.err &&
				$wildtest_test_stdout_stderr_cmp
			"
		else
			test_expect_failure "$match_function (via ls-files): match skip '$pattern' '$text'" 'false'
		fi
	elif test "$match_expect" = 0
	then
		if test -e .git/created_test_file
		then
			test_expect_success "$match_function (via ls-files): no match '$pattern' '$text'" "
				>expect &&
				git$ls_files_args ls-files -z -- '$pattern' >actual.raw 2>actual.err &&
				$wildtest_test_stdout_stderr_cmp
			"
		else
			test_expect_failure "$match_function (via ls-files): no match skip '$pattern' '$text'" 'false'
		fi
	else
		test_expect_success "PANIC: Test framework error. Unknown matches value $match_expect" 'false'
	fi
}

wildtest() {
	if test "$#" = 6
	then
		# When test-wildmatch and git ls-files produce the same
		# result.
		match_glob=$1
		match_file_glob=$match_glob
		match_iglob=$2
		match_file_iglob=$match_iglob
		match_pathmatch=$3
		match_file_pathmatch=$match_pathmatch
		match_pathmatchi=$4
		match_file_pathmatchi=$match_pathmatchi
		text=$5
		pattern=$6
	elif test "$#" = 10
	then
		match_glob=$1
		match_iglob=$2
		match_pathmatch=$3
		match_pathmatchi=$4
		match_file_glob=$5
		match_file_iglob=$6
		match_file_pathmatch=$7
		match_file_pathmatchi=$8
		text=$9
		pattern=${10}
	fi

	test_expect_success 'cleanup after previous file test' '
		if test -e .git/created_test_file
		then
			git reset &&
			git clean -df
		fi
	'

	printf '%s' "$text" >.git/expected_test_file

# TODO: Try to just do this with a tree objects:
# u hello (master) $ git ls-tree 631d134796e8e528cec8490b71b897827291f1d2
# 100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391    ".\305\207it"
# u hello (master) $ printf "100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\ta[bc]d" | git mktree
# b79dc4f6bccebd02e48d27658be9072edbdfad91
# u hello (master) $ ^C
# u hello (master) $ git ls-tree b79dc4f6bccebd02e48d27658be9072edbdfad91
# 100644 blob e69de29bb2d1d6434b8b29ae775ad8c2e48c5391    a[bc]d
# u hello (master) $ git read-tree 631d134796e8e528cec8490b71b897827291f1d2
# u hello (master) $ git st
# AD ".\305\207it"
# ?? foo
# u hello (master) $ git read-tree b79dc4f6bccebd02e48d27658be9072edbdfad91
# u hello (master) $ git st
# AD a[bc]d
# ?? foo
# u hello (master) $ git ls-files 'a*d'
# a[bc]d
# u hello (master) $ git reset
# u hello (master) $ git st
# ?? foo


	test_expect_success "setup wildtest file test for $text" '
		file=$(cat .git/expected_test_file) &&
		if should_create_test_file "$file"
		then
			dirs=${file%/*}
			if test "$file" != "$dirs"
			then
				mkdir -p -- "$dirs" &&
				touch -- "./$text"
			else
				touch -- "./$file"
			fi &&
			git add -A &&
			printf "%s" "$file" >.git/created_test_file
		elif test -e .git/created_test_file
		then
			rm .git/created_test_file
		fi
	'

	# $1: Case sensitive glob match: test-wildmatch & ls-files
	wildtest_test_function "$text" "$pattern" $match_glob "wildmatch"
	wildtest_test_ls_files "$text" "$pattern" $match_file_glob "wildmatch" " --glob-pathspecs"

	# $2: Case insensitive glob match: test-wildmatch & ls-files
	wildtest_test_function "$text" "$pattern" $match_iglob "iwildmatch"
	wildtest_test_ls_files "$text" "$pattern" $match_file_iglob "iwildmatch" " --glob-pathspecs --icase-pathspecs"

	# $3: Case sensitive path match: test-wildmatch & ls-files
	wildtest_test_function "$text" "$pattern" $match_pathmatch "pathmatch"
	wildtest_test_ls_files "$text" "$pattern" $match_file_pathmatch "pathmatch" ""

	# $4: Case insensitive path match: test-wildmatch & ls-files
	wildtest_test_function "$text" "$pattern" $match_pathmatchi "ipathmatch"
	wildtest_test_ls_files "$text" "$pattern" $match_file_pathmatchi "ipathmatch" " --icase-pathspecs"
}

# Basic wildmatch features
wildtest 1 1 1 1 foo foo
wildtest 0 0 0 0 foo bar
wildtest 1 1 1 1 '' ""
wildtest 1 1 1 1 foo '???'
wildtest 0 0 0 0 foo '??'
wildtest 1 1 1 1 foo '*'
wildtest 1 1 1 1 foo 'f*'
wildtest 0 0 0 0 foo '*f'
wildtest 1 1 1 1 foo '*foo*'
wildtest 1 1 1 1 foobar '*ob*a*r*'
wildtest 1 1 1 1 aaaaaaabababab '*ab'
wildtest 1 1 1 1 'foo*' 'foo\*'
wildtest 0 0 0 0 foobar 'foo\*bar'
wildtest 1 1 1 1 'f\oo' 'f\\oo'
wildtest 1 1 1 1 ball '*[al]?'
wildtest 0 0 0 0 ten '[ten]'
wildtest 0 0 1 1 ten '**[!te]'
wildtest 0 0 0 0 ten '**[!ten]'
wildtest 1 1 1 1 ten 't[a-g]n'
wildtest 0 0 0 0 ten 't[!a-g]n'
wildtest 1 1 1 1 ton 't[!a-g]n'
wildtest 1 1 1 1 ton 't[^a-g]n'
wildtest 1 1 1 1 'a]b' 'a[]]b'
wildtest 1 1 1 1 a-b 'a[]-]b'
wildtest 1 1 1 1 'a]b' 'a[]-]b'
wildtest 0 0 0 0 aab 'a[]-]b'
wildtest 1 1 1 1 aab 'a[]a-]b'
wildtest 1 1 1 1 ']' ']'

# Extended slash-matching features
wildtest 0 0 1 1 'foo/baz/bar' 'foo*bar'
wildtest 0 0 1 1 'foo/baz/bar' 'foo**bar'
wildtest 0 0 1 1 'foobazbar' 'foo**bar'
wildtest 1 1 1 1 'foo/baz/bar' 'foo/**/bar'
wildtest 1 1 0 0 'foo/baz/bar' 'foo/**/**/bar'
wildtest 1 1 1 1 'foo/b/a/z/bar' 'foo/**/bar'
wildtest 1 1 1 1 'foo/b/a/z/bar' 'foo/**/**/bar'
wildtest 1 1 0 0 'foo/bar' 'foo/**/bar'
wildtest 1 1 0 0 'foo/bar' 'foo/**/**/bar'
wildtest 0 0 1 1 'foo/bar' 'foo?bar'
wildtest 0 0 1 1 'foo/bar' 'foo[/]bar'
wildtest 0 0 1 1 'foo/bar' 'foo[^a-z]bar'
wildtest 0 0 1 1 'foo/bar' 'f[^eiu][^eiu][^eiu][^eiu][^eiu]r'
wildtest 1 1 1 1 'foo-bar' 'f[^eiu][^eiu][^eiu][^eiu][^eiu]r'
wildtest 1 1 0 0 'foo' '**/foo'
wildtest 1 1 1 1 'XXX/foo' '**/foo'
wildtest 1 1 1 1 'bar/baz/foo' '**/foo'
wildtest 0 0 1 1 'bar/baz/foo' '*/foo'
wildtest 0 0 1 1 'foo/bar/baz' '**/bar*'
wildtest 1 1 1 1 'deep/foo/bar/baz' '**/bar/*'
wildtest 0 0 1 1 'deep/foo/bar/baz/' '**/bar/*'
wildtest 1 1 1 1 'deep/foo/bar/baz/' '**/bar/**'
wildtest 0 0 0 0 'deep/foo/bar' '**/bar/*'
wildtest 1 1 1 1 'deep/foo/bar/' '**/bar/**'
wildtest 0 0 1 1 'foo/bar/baz' '**/bar**'
wildtest 1 1 1 1 'foo/bar/baz/x' '*/bar/**'
wildtest 0 0 1 1 'deep/foo/bar/baz/x' '*/bar/**'
wildtest 1 1 1 1 'deep/foo/bar/baz/x' '**/bar/*/*'

# Various additional tests
wildtest 0 0 0 0 'acrt' 'a[c-c]st'
wildtest 1 1 1 1 'acrt' 'a[c-c]rt'
wildtest 0 0 0 0 ']' '[!]-]'
wildtest 1 1 1 1 'a' '[!]-]'
wildtest 0 0 0 0 '' '\'
wildtest 0 0 0 0 \
	 1 1 1 1 '\' '\'
wildtest 0 0 0 0 'XXX/\' '*/\'
wildtest 1 1 1 1 'XXX/\' '*/\\'
wildtest 1 1 1 1 'foo' 'foo'
wildtest 1 1 1 1 '@foo' '@foo'
wildtest 0 0 0 0 'foo' '@foo'
wildtest 1 1 1 1 '[ab]' '\[ab]'
wildtest 1 1 1 1 '[ab]' '[[]ab]'
wildtest 1 1 1 1 '[ab]' '[[:]ab]'
wildtest 0 0 0 0 '[ab]' '[[::]ab]'
wildtest 1 1 1 1 '[ab]' '[[:digit]ab]'
wildtest 1 1 1 1 '[ab]' '[\[:]ab]'
wildtest 1 1 1 1 '?a?b' '\??\?b'
wildtest 1 1 1 1 'abc' '\a\b\c'
wildtest 0 0 0 0 \
	 E E E E 'foo' ''
wildtest 1 1 1 1 'foo/bar/baz/to' '**/t[o]'

# Character class tests
wildtest 1 1 1 1 'a1B' '[[:alpha:]][[:digit:]][[:upper:]]'
wildtest 0 1 0 1 'a' '[[:digit:][:upper:][:space:]]'
wildtest 1 1 1 1 'A' '[[:digit:][:upper:][:space:]]'
wildtest 1 1 1 1 '1' '[[:digit:][:upper:][:space:]]'
wildtest 0 0 0 0 '1' '[[:digit:][:upper:][:spaci:]]'
wildtest 1 1 1 1 ' ' '[[:digit:][:upper:][:space:]]'
wildtest 0 0 0 0 '.' '[[:digit:][:upper:][:space:]]'
wildtest 1 1 1 1 '.' '[[:digit:][:punct:][:space:]]'
wildtest 1 1 1 1 '5' '[[:xdigit:]]'
wildtest 1 1 1 1 'f' '[[:xdigit:]]'
wildtest 1 1 1 1 'D' '[[:xdigit:]]'
wildtest 1 1 1 1 '_' '[[:alnum:][:alpha:][:blank:][:cntrl:][:digit:][:graph:][:lower:][:print:][:punct:][:space:][:upper:][:xdigit:]]'
wildtest 1 1 1 1 '.' '[^[:alnum:][:alpha:][:blank:][:cntrl:][:digit:][:lower:][:space:][:upper:][:xdigit:]]'
wildtest 1 1 1 1 '5' '[a-c[:digit:]x-z]'
wildtest 1 1 1 1 'b' '[a-c[:digit:]x-z]'
wildtest 1 1 1 1 'y' '[a-c[:digit:]x-z]'
wildtest 0 0 0 0 'q' '[a-c[:digit:]x-z]'

# Additional tests, including some malformed wildmatch patterns
wildtest 1 1 1 1 ']' '[\\-^]'
wildtest 0 0 0 0 '[' '[\\-^]'
wildtest 1 1 1 1 '-' '[\-_]'
wildtest 1 1 1 1 ']' '[\]]'
wildtest 0 0 0 0 '\]' '[\]]'
wildtest 0 0 0 0 '\' '[\]]'
wildtest 0 0 0 0 'ab' 'a[]b'
wildtest 0 0 0 0 \
	 1 1 1 1 'a[]b' 'a[]b'
wildtest 0 0 0 0 \
	 1 1 1 1 'ab[' 'ab['
wildtest 0 0 0 0 'ab' '[!'
wildtest 0 0 0 0 'ab' '[-'
wildtest 1 1 1 1 '-' '[-]'
wildtest 0 0 0 0 '-' '[a-'
wildtest 0 0 0 0 '-' '[!a-'
wildtest 1 1 1 1 '-' '[--A]'
wildtest 1 1 1 1 '5' '[--A]'
wildtest 1 1 1 1 ' ' '[ --]'
wildtest 1 1 1 1 '$' '[ --]'
wildtest 1 1 1 1 '-' '[ --]'
wildtest 0 0 0 0 '0' '[ --]'
wildtest 1 1 1 1 '-' '[---]'
wildtest 1 1 1 1 '-' '[------]'
wildtest 0 0 0 0 'j' '[a-e-n]'
wildtest 1 1 1 1 '-' '[a-e-n]'
wildtest 1 1 1 1 'a' '[!------]'
wildtest 0 0 0 0 '[' '[]-a]'
wildtest 1 1 1 1 '^' '[]-a]'
wildtest 0 0 0 0 '^' '[!]-a]'
wildtest 1 1 1 1 '[' '[!]-a]'
wildtest 1 1 1 1 '^' '[a^bc]'
wildtest 1 1 1 1 '-b]' '[a-]b]'
wildtest 0 0 0 0 '\' '[\]'
wildtest 1 1 1 1 '\' '[\\]'
wildtest 0 0 0 0 '\' '[!\\]'
wildtest 1 1 1 1 'G' '[A-\\]'
wildtest 0 0 0 0 'aaabbb' 'b*a'
wildtest 0 0 0 0 'aabcaa' '*ba*'
wildtest 1 1 1 1 ',' '[,]'
wildtest 1 1 1 1 ',' '[\\,]'
wildtest 1 1 1 1 '\' '[\\,]'
wildtest 1 1 1 1 '-' '[,-.]'
wildtest 0 0 0 0 '+' '[,-.]'
wildtest 0 0 0 0 '-.]' '[,-.]'
wildtest 1 1 1 1 '2' '[\1-\3]'
wildtest 1 1 1 1 '3' '[\1-\3]'
wildtest 0 0 0 0 '4' '[\1-\3]'
wildtest 1 1 1 1 '\' '[[-\]]'
wildtest 1 1 1 1 '[' '[[-\]]'
wildtest 1 1 1 1 ']' '[[-\]]'
wildtest 0 0 0 0 '-' '[[-\]]'

# Test recursion
wildtest 1 1 1 1 '-adobe-courier-bold-o-normal--12-120-75-75-m-70-iso8859-1' '-*-*-*-*-*-*-12-*-*-*-m-*-*-*'
wildtest 0 0 0 0 '-adobe-courier-bold-o-normal--12-120-75-75-X-70-iso8859-1' '-*-*-*-*-*-*-12-*-*-*-m-*-*-*'
wildtest 0 0 0 0 '-adobe-courier-bold-o-normal--12-120-75-75-/-70-iso8859-1' '-*-*-*-*-*-*-12-*-*-*-m-*-*-*'
wildtest 1 1 1 1 'XXX/adobe/courier/bold/o/normal//12/120/75/75/m/70/iso8859/1' 'XXX/*/*/*/*/*/*/12/*/*/*/m/*/*/*'
wildtest 0 0 0 0 'XXX/adobe/courier/bold/o/normal//12/120/75/75/X/70/iso8859/1' 'XXX/*/*/*/*/*/*/12/*/*/*/m/*/*/*'
wildtest 1 1 1 1 'abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txt' '**/*a*b*g*n*t'
wildtest 0 0 0 0 'abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txtz' '**/*a*b*g*n*t'
wildtest 0 0 0 0 foo '*/*/*'
wildtest 0 0 0 0 foo/bar '*/*/*'
wildtest 1 1 1 1 foo/bba/arr '*/*/*'
wildtest 0 0 1 1 foo/bb/aa/rr '*/*/*'
wildtest 1 1 1 1 foo/bb/aa/rr '**/**/**'
wildtest 1 1 1 1 abcXdefXghi '*X*i'
wildtest 0 0 1 1 ab/cXd/efXg/hi '*X*i'
wildtest 1 1 1 1 ab/cXd/efXg/hi '*/*X*/*/*i'
wildtest 1 1 1 1 ab/cXd/efXg/hi '**/*X*/**/*i'

# Extra pathmatch tests
wildtest 0 0 0 0 foo fo
wildtest 1 1 1 1 foo/bar foo/bar
wildtest 1 1 1 1 foo/bar 'foo/*'
wildtest 0 0 1 1 foo/bba/arr 'foo/*'
wildtest 1 1 1 1 foo/bba/arr 'foo/**'
wildtest 0 0 1 1 foo/bba/arr 'foo*'
wildtest 0 0 1 1 \
	 1 1 1 1 foo/bba/arr 'foo**'
wildtest 0 0 1 1 foo/bba/arr 'foo/*arr'
wildtest 0 0 1 1 foo/bba/arr 'foo/**arr'
wildtest 0 0 0 0 foo/bba/arr 'foo/*z'
wildtest 0 0 0 0 foo/bba/arr 'foo/**z'
wildtest 0 0 1 1 foo/bar 'foo?bar'
wildtest 0 0 1 1 foo/bar 'foo[/]bar'
wildtest 0 0 1 1 foo/bar 'foo[^a-z]bar'
wildtest 0 0 1 1 ab/cXd/efXg/hi '*Xg*i'

# Extra case-sensitivity tests
wildtest 0 1 0 1 'a' '[A-Z]'
wildtest 1 1 1 1 'A' '[A-Z]'
wildtest 0 1 0 1 'A' '[a-z]'
wildtest 1 1 1 1 'a' '[a-z]'
wildtest 0 1 0 1 'a' '[[:upper:]]'
wildtest 1 1 1 1 'A' '[[:upper:]]'
wildtest 0 1 0 1 'A' '[[:lower:]]'
wildtest 1 1 1 1 'a' '[[:lower:]]'
wildtest 0 1 0 1 'A' '[B-Za]'
wildtest 1 1 1 1 'a' '[B-Za]'
wildtest 0 1 0 1 'A' '[B-a]'
wildtest 1 1 1 1 'a' '[B-a]'
wildtest 0 1 0 1 'z' '[Z-y]'
wildtest 1 1 1 1 'Z' '[Z-y]'

test_done
