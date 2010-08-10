#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='git status'

. ./test-lib.sh

test_expect_success 'setup' '
	>tracked &&
	>modified &&
	mkdir dir1 &&
	>dir1/tracked &&
	>dir1/modified &&
	mkdir dir2 &&
	>dir1/tracked &&
	>dir1/modified &&
	git add . &&

	git status >output &&

	test_tick &&
	git commit -m initial &&
	>untracked &&
	>dir1/untracked &&
	>dir2/untracked &&
	echo 1 >dir1/modified &&
	echo 2 >dir2/modified &&
	echo 3 >dir2/added &&
	git add dir2/added
'

test_expect_success 'status (1)' '
	grep "use \"git rm --cached <file>\.\.\.\" to unstage" output
'

test_expect_success 'status (2)' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF

	git status >output &&
	test_cmp expect output
'

test_expect_success 'status (advice.statusHints false)' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#	modified:   dir1/modified
	#
	# Untracked files:
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF
	git config advice.statusHints false &&
	test_when_finished "git config --unset advice.statusHints" &&

	git status >output &&
	test_cmp expect output
'

test_expect_success 'status -s' '
	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF

	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'status -s -b' '
	cat >expect <<-\EOF &&
	## master
	 M dir1/modified
	A  dir2/added
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF

	git status -s -b >output &&
	test_cmp expect output
'

test_expect_success 'set up dir3 for untracked files tests' '
	mkdir dir3 &&
	>dir3/untracked1 &&
	>dir3/untracked2 &&

	cat >expect <<-\EOF
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files not listed (use -u option to show untracked files)
	EOF
'

test_expect_success 'status -uno' '
	git status -uno >output &&
	test_cmp expect output
'

test_expect_success 'status (status.showUntrackedFiles no)' '
	git config status.showuntrackedfiles no &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status >output &&
	test_cmp expect output
'

test_expect_success 'status -uno (advice.statusHints false)' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#	modified:   dir1/modified
	#
	# Untracked files not listed
	EOF
	git config status.showuntrackedfiles no &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git config advice.statusHints false &&
	test_when_finished "git config --unset advice.statusHints" &&
	git status -uno >output &&
	test_cmp expect output
'

test_expect_success 'setup: status -s -uno expected output' '
	cat >expect <<-\EOF
	 M dir1/modified
	A  dir2/added
	EOF
'

test_expect_success 'status -s -uno' '
	test_might_fail git config --unset status.showuntrackedfiles &&
	git status -s -uno >output &&
	test_cmp expect output
'

test_expect_success 'status -s (status.showUntrackedFiles no)' '
	git config status.showuntrackedfiles no &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'setup: status -unormal expected output' '
	cat >expect <<-\EOF
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	dir3/
	#	expect
	#	output
	#	untracked
	EOF
'

test_expect_success 'status -unormal' '
	git config status.showuntrackedfiles no &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status -unormal >output &&
	test_cmp expect output
'

test_expect_success 'status (status.showUntrackedFiles normal)' '
	git config status.showuntrackedfiles normal &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status >output &&
	test_cmp expect output
'

test_expect_success 'setup: status -s -unormal expected output' '
	cat >expect <<-\EOF
	 M dir1/modified
	A  dir2/added
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? dir3/
	?? expect
	?? output
	?? untracked
	EOF
'

test_expect_success 'status -s -unormal' '
	test_might_fail git config --unset status.showuntrackedfiles &&
	git status -s -unormal >output &&
	test_cmp expect output
'

test_expect_success 'status -s (status.showUntrackedFiles normal)' '
	git config status.showuntrackedfiles normal &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'setup: status -uall expected output' '
	cat >expect <<-\EOF
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	dir3/untracked1
	#	dir3/untracked2
	#	expect
	#	output
	#	untracked
	EOF
'

test_expect_success 'status -uall' '
	git status -uall >output &&
	test_cmp expect output
'
test_expect_success 'status (status.showUntrackedFiles all)' '
	git config status.showuntrackedfiles all &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status >output &&
	rm -rf dir3 &&
	test_cmp expect output
'

test_expect_success 'setup: status -s -uall expected output' '
	cat >expect <<-\EOF
	 M dir1/modified
	A  dir2/added
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF
'

test_expect_success 'status -s -uall' '
	test_might_fail git config --unset status.showuntrackedfiles &&
	git status -s -uall >output &&
	test_cmp expect output
'

test_expect_success 'status -s (status.showUntrackedFiles all)' '
	git config status.showuntrackedfiles all &&
	test_when_finished "git config --unset status.showuntrackedfiles" &&
	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'setup: done with dir3' '
	rm -rf dir3
'

test_expect_success 'status with relative paths' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   ../dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	untracked
	#	../dir2/modified
	#	../dir2/untracked
	#	../expect
	#	../output
	#	../untracked
	EOF

	(
		cd dir1 &&
		git status >../output
	) &&
	test_cmp expect output
'

test_expect_success 'status -s with relative paths' '
	cat >expect <<-\EOF &&
	 M modified
	A  ../dir2/added
	?? untracked
	?? ../dir2/modified
	?? ../dir2/untracked
	?? ../expect
	?? ../output
	?? ../untracked
	EOF

	(
		cd dir1 &&
		git status -s >../output
	) &&
	test_cmp expect output
'

test_expect_success 'status --porcelain ignores relative paths setting' '
	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF

	(
		cd dir1 &&
		git status --porcelain >../output
	) &&
	test_cmp expect output
'

test_expect_success 'setup: unique colors' '
	git config status.color.untracked blue
'

test_expect_success 'setup: expect colorful output' '
	cat >expect <<-\EOF
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	<GREEN>new file:   dir2/added<RESET>
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	<RED>modified:   dir1/modified<RESET>
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	<BLUE>actual<RESET>
	#	<BLUE>dir1/untracked<RESET>
	#	<BLUE>dir2/modified<RESET>
	#	<BLUE>dir2/untracked<RESET>
	#	<BLUE>expect<RESET>
	#	<BLUE>output<RESET>
	#	<BLUE>untracked<RESET>
	EOF
'

test_expect_success 'status with color.ui' '
	git config color.ui always &&
	test_when_finished "git config --unset color.ui" &&
	git status >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'status with color.status' '
	test_might_fail git config --unset color.ui &&
	git config color.status always &&
	test_when_finished "git config --unset color.status" &&
	git status >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'setup: expected colorful short output' '
	cat >expect <<-\EOF
	 <RED>M<RESET> dir1/modified
	<GREEN>A<RESET>  dir2/added
	<BLUE>??<RESET> actual
	<BLUE>??<RESET> dir1/untracked
	<BLUE>??<RESET> dir2/modified
	<BLUE>??<RESET> dir2/untracked
	<BLUE>??<RESET> expect
	<BLUE>??<RESET> output
	<BLUE>??<RESET> untracked
	EOF
'

test_expect_success 'status -s with color.ui' '
	test_might_fail git config --unset color.status &&
	git config color.ui always &&
	test_when_finished "git config --unset color.ui" &&
	git status -s >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'status -s with color.status' '
	test_might_fail git config --unset color.ui &&
	git config color.status always &&
	test_when_finished "git config --unset color.status" &&
	git status -s >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'status -s -b with color.status' '
	cat >expect <<-\EOF &&
	## <GREEN>master<RESET>
	 <RED>M<RESET> dir1/modified
	<GREEN>A<RESET>  dir2/added
	<BLUE>??<RESET> actual
	<BLUE>??<RESET> dir1/untracked
	<BLUE>??<RESET> dir2/modified
	<BLUE>??<RESET> dir2/untracked
	<BLUE>??<RESET> expect
	<BLUE>??<RESET> output
	<BLUE>??<RESET> untracked
	EOF

	git config color.status always &&
	test_when_finished "git config --unset color.status" &&
	git status -s -b >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'setup: expect uncolorful status --porcelain output' '
	cat >expect <<-\EOF
	 M dir1/modified
	A  dir2/added
	?? actual
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF
'

test_expect_success 'status --porcelain ignores color.ui' '
	test_might_fail git config --unset color.status &&
	git config color.ui always &&
	test_when_finished "git config --unset color.ui" &&
	git status --porcelain >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'status --porcelain ignores color.status' '
	test_might_fail git config --unset color.ui &&
	git config color.status always &&
	test_when_finished "git config --unset color.status" &&
	git status --porcelain >actual &&
	test_decode_color <actual >output &&
	test_cmp expect output
'

test_expect_success 'setup: recover unconditionally from color tests' '
	test_might_fail git config --unset color.status &&
	test_might_fail git config --unset color.ui
'

test_expect_success 'status --porcelain ignores -b' '
	git status --porcelain -b >output &&
	test_cmp expect output
'

test_expect_success 'status without relative paths' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF

	git config status.relativePaths false &&
	test_when_finished "git config --unset status.relativePaths" &&
	(
		cd dir1 &&
		git status >../output
	) &&
	test_cmp expect output
'

test_expect_success 'status -s without relative paths' '
	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	?? actual
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF

	git config status.relativePaths false &&
	test_when_finished "git config --unset status.relativePaths" &&
	(
		cd dir1 &&
		git status -s >../output
	) &&
	test_cmp expect output
'

test_expect_success 'dry-run of partial commit excluding new file in index' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/
	#	expect
	#	output
	#	untracked
	EOF

	git commit --dry-run dir1/modified >output &&
	test_cmp expect output
'

test_expect_success 'status refreshes the index' '
	EMPTY_BLOB=$(git hash-object -t blob --stdin </dev/null) &&
	ZEROES=0000000000000000000000000000000000000000 &&
	echo ":100644 100644 $EMPTY_BLOB $ZEROES M	dir1/modified" >expect &&

	touch dir2/added &&
	git status &&
	git diff-files >output &&
	test_cmp expect output
'

test_expect_success 'setup status submodule summary' '
	test_create_repo sm &&
	(
		cd sm &&
		>foo &&
		git add foo &&
		git commit -m "Add foo"
	) &&
	git add sm &&

	cat >expect <<-\EOF
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#	new file:   sm
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF
'

test_expect_success 'status submodule summary is disabled by default' '
	git status >output &&
	test_cmp expect output
'

# we expect the same as the previous test
test_expect_success 'status --untracked-files=all does not show submodule' '
	git status --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'setup status -s submodule summary' '
	cat >expect <<-\EOF
	 M dir1/modified
	A  dir2/added
	A  sm
	?? actual
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF
'

test_expect_success 'status -s submodule summary is disabled by default' '
	git status -s >output &&
	test_cmp expect output
'

# we expect the same as the previous test
test_expect_success 'status -s --untracked-files=all does not show submodule' '
	git status -s --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'setup: save head' '
	head=$(
		cd sm &&
		git rev-parse --short=7 --verify HEAD
	)
'

test_expect_success 'status submodule summary' '
	cat >expect <<-EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD <file>..." to unstage)
	#
	#	new file:   dir2/added
	#	new file:   sm
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Submodule changes to be committed:
	#
	# * sm 0000000...$head (1):
	#   > Add foo
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF

	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status >output &&
	test_cmp expect output
'

test_expect_success 'status -s submodule summary' '
	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	A  sm
	?? actual
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF

	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'status submodule summary (clean submodule)' '
	cat >expect <<-\EOF &&
	# On branch master
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	no changes added to commit (use "git add" and/or "git commit -a")
	EOF

	git commit -m "commit submodule" &&
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	test_must_fail git commit --dry-run >actual &&
	git status >output &&
	test_cmp expect output &&
	echo '\''no changes added to commit (use "git add" and/or "git commit -a")'\'' >expect &&
	test_cmp expect actual
'

test_expect_success 'status -s submodule summary (clean submodule)' '
	cat >expect <<-\EOF &&
	 M dir1/modified
	?? actual
	?? dir1/untracked
	?? dir2/modified
	?? dir2/untracked
	?? expect
	?? output
	?? untracked
	EOF
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status -s >output &&
	test_cmp expect output
'

test_expect_success 'commit --dry-run submodule summary (--amend)' '
	cat >expect <<-EOF &&
	# On branch master
	# Changes to be committed:
	#   (use "git reset HEAD^1 <file>..." to unstage)
	#
	#	new file:   dir2/added
	#	new file:   sm
	#
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Submodule changes to be committed:
	#
	# * sm 0000000...$head (1):
	#   > Add foo
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	EOF

	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git commit --dry-run --amend >output &&
	test_cmp expect output
'

test_expect_success POSIXPERM,SANITY 'status succeeds in a read-only repository' '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&

	chmod a-w .git &&
	test_when_finished "chmod 775 .git" &&

	# make dir1/tracked stat-dirty
	>dir1/tracked1 &&
	mv -f dir1/tracked1 dir1/tracked &&

	git status -s >output &&
	! grep dir1/tracked output &&

	# make sure "status" succeeded without writing index out
	git diff-files >output &&
	grep dir1/tracked output
'

test_expect_success 'setup: status --ignore-submodules' '
	cat >expect <<-\EOF
	# On branch master
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	no changes added to commit (use "git add" and/or "git commit -a")
	EOF
'

test_expect_success '--ignore-submodules=untracked suppresses submodules with untracked content' '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	echo modified >sm/untracked &&
	git status --ignore-submodules=untracked >output &&
	test_cmp expect output
'

test_expect_success '--ignore-submodules=dirty suppresses submodules with untracked content' '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status --ignore-submodules=dirty >output &&
	test_cmp expect output
'

test_expect_success '--ignore-submodules=dirty suppresses submodules with modified content' '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	echo modified >sm/foo &&
	git status --ignore-submodules=dirty > output &&
	test_cmp expect output
'

test_expect_success "--ignore-submodules=untracked doesn't suppress submodules with modified content" '
	cat >expect <<-\EOF &&
	# On branch master
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#   (commit or discard the untracked or modified content in submodules)
	#
	#	modified:   dir1/modified
	#	modified:   sm (modified content)
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	no changes added to commit (use "git add" and/or "git commit -a")
	EOF
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status --ignore-submodules=untracked >output &&
	test_cmp expect output
'

test_expect_success 'setup' '
	head2=$(
		cd sm &&
		git commit -q -m "2nd commit" foo &&
		git rev-parse --short=7 --verify HEAD
	) &&
	cat >expect <<-EOF
	# On branch master
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#	modified:   sm (new commits)
	#
	# Submodules changed but not updated:
	#
	# * sm $head...$head2 (1):
	#   > 2nd commit
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	no changes added to commit (use "git add" and/or "git commit -a")
	EOF
'

test_expect_success "--ignore-submodules=untracked doesn't suppress submodule summary" '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status --ignore-submodules=untracked >output &&
	test_cmp expect output
'

test_expect_success "--ignore-submodules=dirty doesn't suppress submodule summary" '
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status --ignore-submodules=dirty > output &&
	test_cmp expect output
'

test_expect_success "--ignore-submodules=all suppresses submodule summary" '
	cat >expect <<-\EOF &&
	# On branch master
	# Changed but not updated:
	#   (use "git add <file>..." to update what will be committed)
	#   (use "git checkout -- <file>..." to discard changes in working directory)
	#
	#	modified:   dir1/modified
	#
	# Untracked files:
	#   (use "git add <file>..." to include in what will be committed)
	#
	#	actual
	#	dir1/untracked
	#	dir2/modified
	#	dir2/untracked
	#	expect
	#	output
	#	untracked
	no changes added to commit (use "git add" and/or "git commit -a")
	EOF
	git config status.submodulesummary 10 &&
	test_when_finished "git config --unset status.submodulesummary" &&
	git status --ignore-submodules=all >output &&
	test_cmp expect output
'

test_done
