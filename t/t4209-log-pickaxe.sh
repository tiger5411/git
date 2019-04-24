#!/bin/sh

test_description='log --grep/--author/--regexp-ignore-case/-S/-G'
. ./test-lib.sh

test_log () {
	expect=$1
	kind=$2
	needle=$3
	shift 3
	rest=$@

	case $kind in
	--*)
		opt=$kind=$needle
		;;
	*)
		opt=$kind$needle
		;;
	esac
	case $expect in
	expect_nomatch)
		match=nomatch
		;;
	*)
		match=match
		;;
	esac

	test_expect_success "log $kind${rest:+ $rest} ($match)" "
		git log $rest $opt --format=%H >actual &&
		test_cmp $expect actual
	"
}

# test -i and --regexp-ignore-case and expect both to behave the same way
test_log_icase () {
	test_log $@ --regexp-ignore-case
	test_log $@ -i
}

test_expect_success setup '
	>expect_nomatch &&

	>file &&
	git add file &&
	test_tick &&
	git commit -m initial &&
	git rev-parse --verify HEAD >expect_initial &&

	echo Picked >file &&
	git add file &&
	test_tick &&
	git commit --author="Another Person <another@example.com>" -m second &&
	git rev-parse --verify HEAD >expect_second
'

test_log	expect_initial	--grep initial
test_log	expect_nomatch	--grep InItial
test_log_icase	expect_initial	--grep InItial
test_log_icase	expect_nomatch	--grep initail

test_log	expect_second	--author Person
test_log	expect_nomatch	--author person
test_log_icase	expect_second	--author person
test_log_icase	expect_nomatch	--author spreon

test_log	expect_nomatch	-G picked
test_log	expect_second	-G Picked
test_log_icase	expect_nomatch	-G pickle
test_log_icase	expect_second	-G picked

test_expect_success 'log -G --textconv (missing textconv tool)' '
	echo "* diff=test" >.gitattributes &&
	test_must_fail git -c diff.test.textconv=missing log -Gfoo &&
	rm .gitattributes
'

test_expect_success 'log -G --no-textconv (missing textconv tool)' '
	echo "* diff=test" >.gitattributes &&
	git -c diff.test.textconv=missing log -Gfoo --no-textconv >actual &&
	test_cmp expect_nomatch actual &&
	rm .gitattributes
'

test_log	expect_nomatch	-S picked
test_log	expect_second	-S Picked
test_log_icase	expect_second	-S picked
test_log_icase	expect_nomatch	-S pickle

test_log	expect_nomatch	-S p.cked --pickaxe-regex
test_log	expect_second	-S P.cked --pickaxe-regex
test_log_icase	expect_second	-S p.cked --pickaxe-regex
test_log_icase	expect_nomatch	-S p.ckle --pickaxe-regex

test_expect_success 'log -S --textconv (missing textconv tool)' '
	echo "* diff=test" >.gitattributes &&
	test_must_fail git -c diff.test.textconv=missing log -Sfoo &&
	rm .gitattributes
'

test_expect_success 'log -S --no-textconv (missing textconv tool)' '
	echo "* diff=test" >.gitattributes &&
	git -c diff.test.textconv=missing log -Sfoo --no-textconv >actual &&
	test_cmp expect_nomatch actual &&
	rm .gitattributes
'

test_expect_success 'setup log -[GS] binary & --text' '
	git checkout --orphan GS-binary-and-text &&
	git read-tree --empty &&
	printf "a\na\0a\n" >data.bin &&
	git add data.bin &&
	git commit -m "create binary file" data.bin &&
	printf "a\na\0a\n" >>data.bin &&
	git commit -m "modify binary file" data.bin &&
	git rm data.bin &&
	git commit -m "delete binary file" data.bin &&
	git log >full-log
'

test_expect_success 'log -G ignores binary files' '
	git log -Ga >log &&
	test_must_be_empty log
'

test_expect_success 'log -G looks into binary files with -a' '
	git log -a -Ga >log &&
	test_cmp log full-log
'

test_expect_success 'log -G looks into binary files with textconv filter' '
	test_when_finished "rm .gitattributes" &&
	echo "* diff=bin" >.gitattributes &&
	git -c diff.bin.textconv=cat log -Ga >log &&
	test_cmp log full-log
'

test_expect_success 'log -S looks into binary files' '
	git log -Sa >log &&
	test_cmp log full-log
'

test_expect_success 'setup log -G --pickaxe-raw-diff' '
	git checkout --orphan G-raw-diff &&
	test_write_lines A B C D E F G >file &&
	git add file &&
	git commit --allow-empty-message file &&
	sed -i -e "s/B/2/" file &&
	git add file &&
	git commit --allow-empty-message file &&
	sed -i -e "s/D/4/" file &&
	git add file &&
	git commit --allow-empty-message file &&
	git rm file &&
	git commit --allow-empty-message &&
	git log --oneline -1 HEAD~0 >file.fourth &&
	git log --oneline -1 HEAD~1 >file.third &&
	git log --oneline -1 HEAD~2 >file.second &&
	git log --oneline -1 HEAD~3 >file.first
'

test_expect_success 'log -G --pickaxe-raw-diff skips header and range information' '
	git log --pickaxe-raw-diff -p -G"(@@|file)" >log &&
	test_must_be_empty log
'

test_expect_success 'log -G --pickaxe-raw-diff searching in context' '
	git log --oneline --pickaxe-raw-diff -G"^ F" -U2 -s >log &&
	test_cmp file.third log &&
	git log --oneline --pickaxe-raw-diff -G"^ F" -U1 -s >log &&
	test_must_be_empty log
'

test_expect_success 'log -G --pickaxe-raw-diff searching added / removed lines (skip create/delete)' '
	git log --oneline --pickaxe-raw-diff -G"^-[D2]" -s HEAD~1 >log &&
	test_cmp file.third log &&
	git log --oneline --pickaxe-raw-diff -G"^\+[D2]" -s -1 >log &&
	test_cmp file.second log
'

test_expect_success 'log -G --pickaxe-raw-diff searching created / deleted files' '
	git log --oneline --pickaxe-raw-diff -G"^\+A" -s >log &&
	test_cmp file.first log &&
	git log --oneline --pickaxe-raw-diff -G"^\-A" -s >log &&
	test_cmp file.fourth log
'

test_done
