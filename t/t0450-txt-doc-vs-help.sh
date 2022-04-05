#!/bin/sh

test_description='compare (unbuilt) Documentation/*.txt to -h output

Run this with --debug to see a summary of where we still fail to make
the two versions consistent with one another.'

. ./test-lib.sh

test_expect_success 'setup: list of builtins' '
	git --list-cmds=builtins >builtins
'

expect_help_to_match_txt() {
	cat >ok <<-\EOF &&
	bugreport
	cat-file
	check-attr
	check-ignore
	check-mailmap
	cherry
	cherry-pick
	clean
	count-objects
	describe
	diff
	difftool
	fetch
	for-each-repo
	get-tar-commit-id
	help
	hook
	ls-remote
	merge-base
	merge-index
	merge-tree
	mktag
	mktree
	mv
	pack-redundant
	pack-refs
	patch-id
	prune
	prune-packed
	pull
	read-tree
	replace
	rerere
	revert
	send-pack
	show-index
	sparse-checkout
	status
	stripspace
	symbolic-ref
	tag
	unpack-file
	unpack-objects
	update-server-info
	upload-archive
	upload-pack
	var
	verify-commit
	verify-pack
	verify-tag
	version
	write-tree
	EOF

	sort -u ok >ok.sorted &&
	if ! test_cmp ok ok.sorted
	then
		BUG "please keep the 'ok' list sorted"
	fi &&

	if grep -q "^$1$" ok
	then
		echo success
	else
		echo failure
	fi
}

builtin_to_synopsis () {
	builtin="$1" &&
	test_when_finished "rm -f out" &&
	test_expect_code 129 git $builtin -h >out 2>&1 &&
	sed -n \
		-e '1,/^$/ {
			s/^\(usage\| *or\): //;
			/^$/d;
			p
		}' <out
}

builtin_to_txt () {
	echo "$GIT_BUILD_DIR/Documentation/git-$1.txt"
}

txt_synopsis () {
	sed -n \
		-e '/^\[verse\]$/,/^$/ {
			/^\[verse\]$/d;
			/^$/d;
			s/^'\''\(git[ a-z-]*\)'\''/\1/;
			p;
		}' \
		<"$1"
}

HT="	"
align_after_nl () {
	builtin="$1" &&
	len=$(printf "git %s " "$builtin" | wc -c) &&
	pad=$(printf "%${len}s" "") &&

	sed "s/^[ $HT][ $HT]*/$pad/"
}

test_debug '>failing'
while read builtin
do
	txt="$(builtin_to_txt "$builtin")" &&
	preq="$(echo BUILTIN_TXT_$builtin | tr '[:lower:]-' '[:upper:]_')" &&

	if test -f "$txt"
	then
		test_set_prereq "$preq"
	fi &&

	# Avoid a subshell for expect_help_to_match_txt as it might
	# call BUG().
	expect_help_to_match_txt "$builtin" >expect-result &&
	result=$(cat expect-result) &&

	test_expect_$result "$preq" "$builtin -h output and SYNOPSIS agree" '
		txt_synopsis "$txt" >txt.raw &&
		builtin_to_synopsis "$builtin" >help.raw &&

		# The *.txt and -h use different spacing for the
		# alignment of continued usage output, normalize it.
		align_after_nl "$builtin" <txt.raw >txt &&
		align_after_nl "$builtin" <help.raw >help &&
		test_cmp txt help
	'

	if test_have_prereq "$preq"
	then
		test_debug '
			if test_cmp txt help >cmp
			then
				echo "=== DONE: $builtin ==="
			else
				echo "=== TODO: $builtin ===" &&
				cat cmp
			fi >>failing
		'
	fi
done <builtins

test_debug 'say "$(cat failing)"'

test_done
