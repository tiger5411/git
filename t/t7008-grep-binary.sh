#!/bin/sh

test_description='git grep in binary files'

. ./test-lib.sh

nul_match () {
	matches=$1
	flags=$2
	pattern=$3
	pattern_human=$(echo "$pattern" | sed 's/Q/<NUL>/g')

	if test "$matches" = 1
	then
		test_expect_success "git grep -f f $flags '$pattern_human' a" "
			printf '$pattern' | q_to_nul >f &&
			git grep -f f $flags a
		"
	elif test "$matches" = 0
	then
		test_expect_success "git grep -f f $flags '$pattern_human' a" "
			printf '$pattern' | q_to_nul >f &&
			test_must_fail git grep -f f $flags a
		"
	elif test "$matches" = T1
	then
		test_expect_failure "git grep -f f $flags '$pattern_human' a" "
			printf '$pattern' | q_to_nul >f &&
			git grep -f f $flags a
		"
	elif test "$matches" = T0
	then
		test_expect_failure "git grep -f f $flags '$pattern_human' a" "
			printf '$pattern' | q_to_nul >f &&
			test_must_fail git grep -f f $flags a
		"
	else
		test_expect_success "PANIC: Test framework error. Unknown matches value $matches" 'false'
	fi
}

test_expect_success 'setup' "
	echo 'binaryQfileQm[*]cQ*æQð' | q_to_nul >a &&
	git add a &&
	git commit -m.
"

test_expect_success 'git grep ina a' '
	echo Binary file a matches >expect &&
	git grep ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -ah ina a' '
	git grep -ah ina a >actual &&
	test_cmp a actual
'

test_expect_success 'git grep -I ina a' '
	: >expect &&
	test_must_fail git grep -I ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -c ina a' '
	echo a:1 >expect &&
	git grep -c ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -l ina a' '
	echo a >expect &&
	git grep -l ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -L bar a' '
	echo a >expect &&
	git grep -L bar a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -q ina a' '
	: >expect &&
	git grep -q ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'git grep -F ile a' '
	git grep -F ile a
'

test_expect_success 'git grep -Fi iLE a' '
	git grep -Fi iLE a
'

# This test actually passes on platforms where regexec() supports the
# flag REG_STARTEND.
test_expect_success 'git grep ile a' '
	git grep ile a
'

if test_have_prereq LIBPCRE2_BUNDLED
then
	test_expect_success 'git grep .fi a' '
		git grep .fi a
	'
else
	test_expect_failure 'git grep .fi a' '
		git grep .fi a
	'
fi

nul_match 1 '-F' 'yQf'
nul_match 0 '-F' 'yQx'
nul_match 1 '-Fi' 'YQf'
nul_match 0 '-Fi' 'YQx'
nul_match 1 '' 'yQf'
nul_match 0 '' 'yQx'
nul_match 1 '' 'æQð'
nul_match 1 '-F' 'eQm[*]c'
nul_match 1 '-Fi' 'EQM[*]C'

# Regex patterns that would match but shouldn't with -F
nul_match 0 '-F' 'yQ[f]'
nul_match 0 '-F' '[y]Qf'
nul_match 0 '-Fi' 'YQ[F]'
nul_match 0 '-Fi' '[Y]QF'
nul_match 0 '-F' 'æQ[ð]'
nul_match 0 '-F' '[æ]Qð'
nul_match 0 '-Fi' 'ÆQ[Ð]'
nul_match 0 '-Fi' '[Æ]QÐ'

if test_have_prereq LIBPCRE2
then
	# Regex patterns that should match without -F
	nul_match 1 '' 'yQ[f]'
	nul_match 1 '' '[y]Qf'
	nul_match 1 '-i' 'YQ[F]'
	nul_match 1 '-i' '[Y]Qf'
	nul_match 1 '' 'æQ[ð]'
	nul_match 1 '' '[æ]Qð'
	nul_match 0 '-i' '[Æ]Qð'
	nul_match 1 '' 'eQm.*cQ'
	nul_match 1 '-i' 'EQM.*cQ'
	nul_match 0 '' 'eQm[*]c'
	nul_match 0 '-i' 'EQM[*]C'

	# These should also match, but don't due to some heisenbug,
	# they succeed when run manually!
	nul_match T1 '-i' 'ÆQÐ'
	nul_match T1 '-i' 'ÆQ[Ð]'
else
	# \0 implicitly disables regexes. This is an undocumented
	# internal limitation.
	nul_match T1 '' 'yQ[f]'
	nul_match T1 '' '[y]Qf'
	nul_match T1 '-i' 'YQ[F]'
	nul_match T1 '-i' '[Y]Qf'
	nul_match T1 '' 'æQ[ð]'
	nul_match T1 '' '[æ]Qð'
	nul_match T1 '-i' 'ÆQ[Ð]'

	# ... because of \0 implicitly disabling regexes regexes that
	# should/shouldn't match don't do the right thing.
	nul_match T1 '' 'eQm.*cQ'
	nul_match T1 '-i' 'EQM.*cQ'
	nul_match T0 '' 'eQm[*]c'
	nul_match T0 '-i' 'EQM[*]C'
fi

# Due to the REG_STARTEND extension when kwset() is disabled on -i &
# non-ASCII the string will be matched in its entirety, but the
# pattern will be cut off at the first \0.
nul_match 0 '-i' 'NOMATCHQð'
if test_have_prereq LIBPCRE2
then
	nul_match 0 '-i' '[Æ]QNOMATCH'
	nul_match 0 '-i' '[æ]QNOMATCH'
else
	nul_match T0 '-i' '[Æ]QNOMATCH'
	nul_match T0 '-i' '[æ]QNOMATCH'
fi
# Matches, but for the wrong reasons, just stops at [æ]
if test_have_prereq LIBPCRE2
then
	nul_match T1 '-i' '[Æ]Qð'
else
	nul_match 1 '-i' '[Æ]Qð'
fi
nul_match 1 '-i' '[æ]Qð'

# Ensure that the matcher doesn't regress to something that stops at
# \0
nul_match 0 '-F' 'yQ[f]'
nul_match 0 '-Fi' 'YQ[F]'
nul_match 0 '' 'yQNOMATCH'
nul_match 0 '' 'QNOMATCH'
nul_match 0 '-i' 'YQNOMATCH'
nul_match 0 '-i' 'QNOMATCH'
nul_match 0 '-F' 'æQ[ð]'
nul_match 0 '-Fi' 'ÆQ[Ð]'
nul_match 0 '' 'yQNÓMATCH'
nul_match 0 '' 'QNÓMATCH'
nul_match 0 '-i' 'YQNÓMATCH'
nul_match 0 '-i' 'QNÓMATCH'

test_expect_success 'grep respects binary diff attribute' '
	echo text >t &&
	git add t &&
	echo t:text >expect &&
	git grep text t >actual &&
	test_cmp expect actual &&
	echo "t -diff" >.gitattributes &&
	echo "Binary file t matches" >expect &&
	git grep text t >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached respects binary diff attribute' '
	git grep --cached text t >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached respects binary diff attribute (2)' '
	git add .gitattributes &&
	rm .gitattributes &&
	git grep --cached text t >actual &&
	test_when_finished "git rm --cached .gitattributes" &&
	test_when_finished "git checkout .gitattributes" &&
	test_cmp expect actual
'

test_expect_success 'grep revision respects binary diff attribute' '
	git commit -m new &&
	echo "Binary file HEAD:t matches" >expect &&
	git grep text HEAD -- t >actual &&
	test_when_finished "git reset HEAD^" &&
	test_cmp expect actual
'

test_expect_success 'grep respects not-binary diff attribute' '
	echo binQary | q_to_nul >b &&
	git add b &&
	echo "Binary file b matches" >expect &&
	git grep bin b >actual &&
	test_cmp expect actual &&
	echo "b diff" >.gitattributes &&
	echo "b:binQary" >expect &&
	git grep bin b >actual.raw &&
	nul_to_q <actual.raw >actual &&
	test_cmp expect actual
'

cat >nul_to_q_textconv <<'EOF'
#!/bin/sh
"$PERL_PATH" -pe 'y/\000/Q/' < "$1"
EOF
chmod +x nul_to_q_textconv

test_expect_success 'setup textconv filters' '
	echo a diff=foo >.gitattributes &&
	git config diff.foo.textconv "\"$(pwd)\""/nul_to_q_textconv
'

test_expect_success 'grep does not honor textconv' '
	test_must_fail git grep Qfile
'

test_expect_success 'grep --textconv honors textconv' '
	echo "a:binaryQfileQm[*]cQ*æQð" >expect &&
	git grep --textconv Qfile >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --no-textconv does not honor textconv' '
	test_must_fail git grep --no-textconv Qfile
'

test_expect_success 'grep --textconv blob honors textconv' '
	echo "HEAD:a:binaryQfileQm[*]cQ*æQð" >expect &&
	git grep --textconv Qfile HEAD:a >actual &&
	test_cmp expect actual
'

test_done
