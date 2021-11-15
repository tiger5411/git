#!/bin/sh
set -e
set -x

## Usage:
#
# ./make-install-avargit.sh --only-merge --merge-compile-args "all SANITIZE=leak" --merge-compile-test "make -C t T=t0001-init.sh"
# ./make-install-avargit.sh --only-merge --merge-compile-args "all" --merge-compile-test '(cd t && pwd && ./t0040-parse-options.sh)'

## Options
no_sanity=
no_range_diff=
only_sanity=
range_diff_to=origin/master
only_range_diff=
only_merge=
merge_full_tests=
no_merge_compile=
merge_compile_args="git-objs sparse check-docs"
merge_compile_test=
only_test=
force_push=
auto_rebase=
verbose=
debug=
while test $# != 0
do
	case "$1" in
	--no-range-diff)
		no_range_diff=yes
		;;
	--no-sanity|--no-check)
		no_sanity=yes
		;;
	--only-sanity|--only-check)
		only_sanity=yes
		;;
	--only-range-diff)
		only_range_diff=yes
		;;
	--range-diff-to)
		range_diff_to="$2"
		shift
		;;
	--only-merge)
		only_merge=yes
		;;
	--merge-full-tests)
		merge_full_tests=yes
		;;
	--merge-compile-args)
		merge_compile_args="$2"
		shift
		;;
	--merge-compile-test)
		merge_compile_test="$2"
		shift
		;;
	--no-merge-compile)
		no_merge_compile=yes
		;;
	--only-test)
		only_test=yes
		;;
	--force-push)
		force_push=yes
		;;
	--auto-rebase)
		auto_rebase=yes
		;;
	--verbose)
		verbose=yes
		;;
	--debug)
		debug=yes
		;;
	--*)
		echo "Unknown option $1"
		exit 1
		;;
	*)
		break
		;;
	esac
	shift
done

## Post-process options
range_diff_to_rev=$(git rev-parse "$range_diff_to")

## Startup

META_DIR="$(pwd)"
BUILD_DIR=~/g/git.build
cd $BUILD_DIR
CACHE_DIR=
make_cache () {
	RUNTIME_DIR="$XDG_RUNTIME_DIR"
	if test -z "$RUNTIME_DIR"
	then
		echo should have a XDG_RUNTIME_DIR like /run/$(id -u)
		exit 1
	fi
	BASENAME="$(basename "$0")"
	CACHE_DIR="$RUNTIME_DIR/$BASENAME"
	export CACHE_DIR
	mkdir -p "$CACHE_DIR"
}
make_cache

tag_name() {
	date +'avargit-v%Y-%m-%d-%H%M%S'
}

tag_it() {
	tmp=$(mktemp /tmp/avargit-XXXXX)
	cat >$tmp <<-EOF
	object $1
	type commit
	tag $2
	tagger $(git config user.name) <$(git config user.email)> $(date "+%s %z")

	My personal git version built from (mostly) my outstanding topics.

	The hacky script that built this follows after the NUL, and the
	series.conf after another NUL:
	EOF

	printf "\0" >>$tmp
	cat "$META_DIR"/"$0" >>$tmp
	printf "\0" >>$tmp
	cat "$META_DIR"/series.conf >>$tmp

	git mktag --strict <$tmp
}

reset_it() {
	git reset --hard
	git checkout build-master || git checkout -b build-master -t origin/master
	git bisect reset
	git reset --hard @{u}
	git merge --abort || :
	git reset --hard @{u}
	rm -f version
}

test_compile () {
	full=$1

	make -j $(nproc) $merge_compile_args

	if test -n "$merge_compile_test"
	then
		sh -c "$merge_compile_test"
	fi

	if test -z "$full"
	then
		return
	fi

	# Compile
	make -j $(nproc) all
	make -j $(nproc) man

	# Test sanity
	make -C t test-lint

	# Remove any past test state
	make -C t clean
	GIT_PROVE_OPTS="--state=save --jobs=$(nproc) --timer"
	export GIT_PROVE_OPTS

	# First run a smaller subset of tests, likelier to have
	# failures. But maybe we're on master, or otherwise have no
	# "t/" modifications, so "test -s".aoo
	git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests
	tr '\n' ' ' </tmp/git.build-tests >/tmp/git.build-tests.tr
	if test -s /tmp/git.build-tests.tr
	then
		(
			cd t
			if ! GIT_TEST_HTTPD=1 make T="$(cat /tmp/git.build-tests.tr)" GIT_PROVE_OPTS="$GIT_PROVE_OPTS"
			then
				suggest_bisect "$(git rev-parse HEAD)"
			fi
		)
	fi

	# Run all tests
	(
		cd t
		make clean-except-prove-cache
		if ! GIT_TEST_HTTPD=1 GIT_TEST_DEFAULT_HASH=sha256 make GIT_PROVE_OPTS="$GIT_PROVE_OPTS --exec /bin/bash"
		then
			suggest_bisect "$(git rev-parse HEAD)"
		fi
	)

	# Run special test setups
	make -j $(nproc) SANITIZE=leak CFLAGS="-O0 -g"
	(
		cd t
		make clean-except-prove-cache
		# TODO: Skipping t0002 because
		# avar/do-not-die-on-setup-gently-2 adds an "git
		# ls-remote" to the test, so it's a "new" but old
		# leak.
		if ! GIT_SKIP_TESTS="t0002 t4131" GIT_TEST_HTTPD=1 GIT_TEST_PASSING_SANITIZE_LEAK=true GIT_TEST_PIPEFAIL=true make GIT_PROVE_OPTS="$GIT_PROVE_OPTS --exec /home/avar/g/bash/bash"
		then
			suggest_bisect "$(git rev-parse HEAD)"
		fi
	)
}

suggest_bisect() {
	rev="$1"
	failed_tests=$(
		cd test-results
		grep -lve '^0$' *.exit | sed 's/\.exit/.sh/' |
		tr '\n' ' ' | sed 's/ $//'
	)

	sed 's/^\t//' >/tmp/git-build-bisect.sh <<EOF
	#!/bin/sh
	set -xe
	cd $BUILD_DIR

	if ! git bisect log 2>/dev/null
	then
		git bisect start
		git bisect good @{upstream}
		git bisect bad $rev
		git bisect run /tmp/git-build-bisect.sh
		exit 0
	fi

	if ! (cd t && stat $failed_tests >/dev/null)
	then
		# New tests? Good
		exit 0
	fi

	~/g/git.meta/config.mak.sh --prefix /home/avar/local
	if ! make -j \$(nproc) all check-docs
	then
		git clean -dxf
		~/g/git.meta/config.mak.sh --prefix /home/avar/local
		if ! make -j \$(nproc) all check-docs
		then
			exit 125
		fi
	fi

	(
		cd t &&
		env \\
			GIT_TEST_HTTPD=1 \\
			GIT_TEST_DEFAULT_HASH=sha256 \\
			make \\
			GIT_PROVE_OPTS="$GIT_PROVE_OPTS --exec /bin/bash" \\
			T="$failed_tests"
	)
EOF
	chmod +x /tmp/git-build-bisect.sh
	sed 's/^\t//' <<EOF
	Try bisect with:

		/tmp/git-build-bisect.sh

	See:

		cat /tmp/git-build-bisect.sh

	for what it'll do
EOF
	exit 1
}

reset_it

# The list of topics I'm merging
if test -z "$debug"
then
	set +x
fi
series_list=$(mktemp /tmp/avargit-series-XXXXX)
grep -v \
	-e '^$' \
	-e '^#' \
	~/g/git.meta/series.conf >$series_list

>$series_list.old-merge

# Sanity check that this is all pushed out
pushed=
while read -r branch
do
	if test -n "$no_sanity$only_range_diff$only_merge"
	then
		continue
	fi

	# Should always have the latest branch
	vless=$(echo "refs/heads/$branch" | sed 's/-[0-9]$//')
	git for-each-ref --format="%(refname)" "$vless*" |
		grep -P "^$vless(?:|-[0-9]+)$" |
		sort -nr >$series_list.vless
	current=$(head -n 1 $series_list.vless)

	if test "refs/heads/$branch" != "$current"
	then
		echo "error: in series.conf I have:"
		echo "	$branch:"
		echo "But should have:"
		echo "	$current" | sed -e 's!refs/heads/!!'
		echo "Found these versions of the series:"
		cat $series_list.vless | sed -e 's!refs/heads/!!'
		exit 1
	fi

	# Should have pushed that latest branch
	git for-each-ref \
		"refs/heads/$branch" "refs/remotes/avar/$branch" >$series_list.vcmp
	if test $(cut -d ' ' -f 1 $series_list.vcmp | sort -u | wc -l) -ne 1
	then
		echo "error: Our upstream of $branch should be the same!"
		echo "error: Got this instead:"
		cat $series_list.vcmp | sed -e 's!refs/heads/!!'
		git push avar $branch:$branch ${force_push:+--force}
		pushed=1
	fi

	# Should always have upstream info
	upstream=$(git for-each-ref --format="%(upstream)" "refs/heads/$branch")
	upstream_short=$(echo $upstream | sed -e 's!refs/remotes/avar/!!' -e 's!refs/remotes/origin/!!')

	# Catch a topic of mine that depends on another topic I've
	# ejected or not listed in series.conf explicitly.
	case "$upstream" in
	refs/remotes/avar/*)
		if ! grep -q -x "$upstream_short" $series_list
		then
			echo "error:	$branch"
			echo "error: depends on:"
			echo "error:	$upstream_short"
			echo "error: but that dependency is not itself in series.conf!"
			exit 1
		fi
		;;
	*)
		;;
	esac

	# Which means we have aheadbehind info
	aheadbehind=$(git for-each-ref --format="%(upstream:trackshort)" "refs/heads/$branch")
	aheadbehind_long=$(git for-each-ref --format="%(upstream:track,nobracket)" "refs/heads/$branch")

	case "$upstream" in
	"refs/heads/*")
		echo "Broken branch config for $branch, has remote=. ?"
		exit 1
		;;
	"")
		echo No upstream setup for $branch
		exit 1
		;;
	refs/remotes/origin/master)
		if test -n "$verbose"
		then
			echo "$branch is $aheadbehind ($aheadbehind_long) of master"
		fi
		;;
	refs/remotes/avar/*|refs/remotes/gitster/*|refs/remotes/ttaylorr/*)
		if test -n "$verbose" && test "$aheadbehind" != ">"
		then
			echo "$branch should be ahead of $upstream_short, am $aheadbehind instead ($aheadbehind_long)"
		fi
		;;
	*)
		echo "WTF @ $branch -> $upstream?"
		exit 1
		;;
	esac

	# --check sanity
	if ! git -P log --no-decorate --oneline --check $upstream..$branch >/dev/null
	then
		# Whitelist branches that have legitimate whitespace
		# issues but have .gitattributes files. TODO: Make
		# "git log" accept a .gitattributes from a given HEAD?
		case "$branch" in
		avar-hanwen/reftable*)
			;;
		*)
			echo "Have bad --check output for $branch:"
			git -P log --oneline --check $upstream..$branch
			;;
		esac
	fi

	# For my own branches not based on "master"
	case "$upstream" in
	refs/remotes/avar/*)
		vless=$(echo "$upstream" | sed 's/-[0-9]$//')
		git for-each-ref --format="%(refname)" "$vless*" |
			grep -P "^$vless(?:|-[0-9]+)$" |
			sort -nr >$series_list.vless
		current=$(head -n 1 $series_list.vless)

		if test "$upstream" != "$current"
		then
			echo "error: $branch depends on:"
			echo "	$upstream_short" | sed 's!refs/remotes/avar/!!'
			echo "but should depend on:"
			echo "	$current" | sed 's!refs/remotes/avar/!!'
			echo "Fix it with:"
			echo "	git checkout $branch &&"
			echo "	git branch --set-upstream-to $current &&" | sed 's!refs/remotes/!!'
			echo "	git rebase --onto $current $upstream_short &&"
			echo "	git push avar HEAD -f"
			echo
			echo "Found these versions of the series:"
			cat $series_list.vless

			exit 1
		fi

		aheadbehind=$(git for-each-ref --format="%(upstream:track,nobracket)" "refs/heads/$branch")
		case "$aheadbehind" in
		*behind*)
			echo "Need to rebase $branch on:"
			echo "	$upstream" | sed 's!refs/remotes/avar/!!'
			echo "It is currently $aheadbehind"
			cat >$series_list.auto-rebase <<-EOF
			git -C ~/g/git checkout $branch &&
			git -C ~/g/git rebase &&
			git -C ~/g/git push avar $branch:$branch ${force_push:+--force}
			EOF
			if test -n "$auto_rebase"
			then
				echo "Doing a rebase with --auto-rebase, script:"
				echo
				cat $series_list.auto-rebase | sed 's/^/	/'
				eval "$(cat $series_list.auto-rebase)"
				pushed=1
			else
				echo "To rebase it, do:"
				echo
				cat $series_list.auto-rebase | sed 's/^/	/'
				exit 1
			fi
			;;
		*ahead*)
			test -n "$verbose" && echo "$branch is $aheadbehind of upstream $upstream"
			;;
		esac

		;;
	*)
		;;
	esac
done <$series_list
test -n "$only_sanity" && exit

# TODO BUG
if test -n "$pushed"
then
	echo "We did pushes in the sanity phase, re-run"
	exit 1
fi

# Check what's already merged
while read -r branch
do
	if test -n "$no_range_diff$only_merge"
	then
		continue
	fi
	branch_rev=$(git rev-parse "$branch")
	f="$CACHE_DIR/range-diff-${range_diff_to_rev}...${branch_rev}.out"
	if ! test -f "$f"
	then
		git --no-pager range-diff --color --no-notes --right-only $range_diff_to...$branch >"$f"
	fi

	if ! test -f "$f".no-new
	then
		grep -E -v -- " ----------+ >" "$f" >"$f".no-new || :
	fi

	if test -s "$f".no-new
	then
		echo "Have partial merge in rangediff of $range_diff_to...$branch, rebase!:"
		cat "$f"
	else
		echo "Have $(wc -l "$f" | cut -d ' ' -f1) unmerged in range-diff of $range_diff_to...$branch"
	fi
done <$series_list
test -n "$only_range_diff" && exit

# Checkout work area
reset_it

# Configure with prefix & cflags, fake "version" still
~/g/git.meta/config.mak.sh --prefix /home/avar/local --cc clang --cflags "-O2 -g"

# Test master first, for basic sanity
if test -z "$no_merge_compile"
then
	test_compile
	if test -n "$merge_full_tests"
	then
		# Exhaustive compile, tests etc.
		test_compile full
	fi
fi

# Merge it all together
set -x
while read -r branch
do
	# If we've got a previous resolution, the merge --continue
	# will continue the merge. TODO: make --continue support
	# --no-edit
	git merge --no-edit $branch || EDITOR=cat git merge --continue

	# Make sure this merge at least compiles
	if test -n "$merge_full_tests"
	then
		# Exhaustive compile, tests etc.
		test_compile full
	elif test -z "$no_merge_compile"
	then
		# Only the basic compile, test etc.
		test_compile
	fi

	if ! test -f config.mak
	then
		echo "WTF? config.mak gone after merging $branch?"
		exit 1
	fi
done <$series_list
test -n "$only_merge" && exit

# Configure with prefix & cflags, and a non-fake "version" for release
rm version
~/g/git.meta/config.mak.sh --do-release --prefix /home/avar/local --cc clang --cflags "-O2 -g"

# Compile, unless we were doing it in the merge loop
if test -z "$merge_full_tests"
then
	test_compile full
fi

# Abort before installation?
test -n "$only_test" && exit

# Install it
new_version=$(git rev-parse HEAD)
new_tagname=$(tag_name)
new_tag=$(tag_it "$(git rev-parse HEAD)" "$new_tagname")
last_version=$(git rev-parse avar/private)
make -j $(nproc) install install-man

# Post-install & report
echo "Range-diff between last built and what I've got now:"
if ! git --no-pager range-diff --left-only avar/private...
then
	echo "Range-diff segfaulting? Upstream issue with integer overflow"
fi

echo "Shortlog from @{u}..:"
git --no-pager shortlog @{u}..

git push avar HEAD:private -f
git push avar $new_tag:refs/built-tags/$new_tagname

echo "Check out the CI result at:"
echo "  https://github.com/avar/git/commit/$new_version"

# Cleanup
rm -rf /tmp/avargit-*
