#!/bin/sh
set -e
set -x

no_range_diff=
only_sanity=
only_range_diff=
only_merge=
only_compile=
only_basic_test=
only_test=
force_push=
auto_rebase=
verbose=
while test $# != 0
do
	case "$1" in
	--no-range-diff)
		no_range_diff=yes
		;;
	--only-sanity)
		only_sanity=yes
		;;
	--only-range-diff)
		only_range_diff=yes
		;;
	--only-merge)
		only_merge=yes
		;;
	--only-compile)
		only_compile=yes
		;;
	--only-basic-test)
		only_basic_test=yes
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
	*)
		break
		;;
	esac
	shift
done

META_DIR="$(pwd)"
BUILD_DIR=~/g/git.build
cd $BUILD_DIR

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

	The hacky script that built this follows after the NUL:
	EOF

	printf "\0" >>$tmp
	cat "$META_DIR"/"$0" >>$tmp

	git mktag --strict <$tmp
}

show_built_from() {
	built_from=$(git version --build-options | grep -P -o '(?<=built from commit: ).*')
	echo "Info:"
	echo "  - Now running: $(git version)"
	echo "  - Now running built from: $(git reference $built_from)"
}

reset_it() {
	git bisect reset
	git reset --hard @{u}
	git merge --abort || :
	git reset --hard @{u}
}

suggest_bisect() {
	failed_tests=$(
		cd test-results
		grep -lve '^0$' *.exit | sed 's/\.exit/.sh/'
	)

	cat >/tmp/git-build-bisect.sh <<-EOF
	#!/bin/sh
	set -xe
	cd $BUILD_DIR

	if ! git bisect log 2>/dev/null
	then
		git bisect start
		git bisect good @{upstream}
		git bisect bad HEAD
		git bisect run /tmp/git-build-bisect.sh
		exit 0
	fi

	make -j $(nproc) all check-docs

	(
		cd t &&
		GIT_TEST_HTTPD=1 GIT_TEST_DEFAULT_HASH=sha256 \
			make GIT_PROVE_OPTS="$GIT_PROVE_OPTS --exec /bin/bash" \
			T="$failed_tests"
	)
	EOF
	chmod +x /tmp/git-build-bisect.sh
	cat <<-EOF
	Try bisect with:

            /tmp/git-build-bisect.sh

        See:

            cat /tmp/git-build-bisect.sh

        for what it'll do
	EOF
	exit 1
}

show_built_from
reset_it
git checkout build-master || git checkout -b build-master -t origin/master

# The list of topics I'm merging
set +x
series_list=$(mktemp /tmp/avargit-series-XXXXX)
grep -v \
     -e '^$' \
     -e '^#' \
     ~/g/git.meta/series.conf >$series_list

>$series_list.old-merge
# Sanity check that this is all pushed out
while read -r branch
do
	# Should always have upstream info
	upstream=$(git for-each-ref --format="%(upstream)" "refs/heads/$branch")
	case "$upstream" in
	refs/remotes/origin/master)
		aheadbehind=$(git for-each-ref --format="%(upstream:track,nobracket)" "refs/heads/$branch")
		test -n "$verbose" && echo "Branch $branch is $aheadbehind upstream master"
		if test -n "$(git rev-list $branch...avar/$branch)"
		then
			git push avar $branch:$branch ${force_push:+--force}
		fi
		# OK
		;;
	"refs/heads/*")
		echo "Broken branch config for $branch, has remote=. ?"
		exit 1
		;;
	"")
		echo No upstream setup for $branch
		exit 1
		;;
	refs/remotes/avar/*)
		vless=$(echo "$upstream" | sed 's/-[0-9]$//')
		git for-each-ref --format="%(refname)" "$vless*" |
			grep -P "^$vless(?:|-[0-9]+)$" |
			sort -nr >$series_list.vless
		current=$(head -n 1 $series_list.vless)

		if test "$upstream" != "$current"
		then
			echo "error: $branch depends on:"
			echo "    $upstream" | sed 's!refs/remotes/avar/!!'
			echo "but should depend on:"
			echo "    $current" | sed 's!refs/remotes/avar/!!'
			echo "Fix it with:"
			echo "    git checkout $branch &&"
			echo "    git branch --set-upstream-to $current &&" | sed 's!refs/remotes/!!'
			echo "    git rebase --onto $current $upstream &&" | sed 's!refs/remotes/!!'
			echo "    git push avar HEAD -f"
			echo
			echo "Found these versions of the series:"
			cat $series_list.vless

			exit 1
		fi

		aheadbehind=$(git for-each-ref --format="%(upstream:track,nobracket)" "refs/heads/$branch")
		case "$aheadbehind" in
		    *behind*)
			    echo "Need to rebase $branch on:"
			    echo "    $upstream" | sed 's!refs/remotes/avar/!!'
			    echo "It is currently $aheadbehind"
			    if test -n "$auto_rebase"
			    then
				    git checkout $branch
				    git rebase
				    # Die if I need to force push, will manually sort it out.
				    echo git push avar $branch:$branch ${force_push:+--force}
			    fi
			    exit 1
			    ;;
		    *ahead*)
			    test -n "$verbose" && echo "Branch $branch is $aheadbehind of upstream $upstream"
			    ;;
		esac

		;;
	*)
		echo "General fail of $branch=$upstream"
		exit 1
	esac
done <$series_list
test -n "$only_sanity" && exit

# Check what's already merged
while read -r branch
do
	if test -n "$no_range_diff"
	then
		continue
	fi
	git --no-pager range-diff --no-notes --right-only origin/master...$branch >$series_list.range-diff
	grep -E -v -- " ----------+ >" $series_list.range-diff >$series_list.range-diff.no-new || :
	if test -s $series_list.range-diff.no-new
	then
		echo "Have partial merge in rangediff of origin/master...$branch, rebase!:"
		cat $series_list.range-diff
	else
		echo "Have $(wc -l $series_list.range-diff | cut -d ' ' -f1) unmerged in range-diff of origin/master...$branch"
	fi
done <$series_list
test -n "$only_range_diff" && exit

# Checkout work area
reset_it
git checkout build-master || git checkout -b build-master -t origin/master

# Merge it all together
set -x
while read -r branch
do
	# If we've got a previous resolution, the merge --continue
	# will continue the merge. TODO: make --continue support
	# --no-edit
	git merge --no-edit $branch || EDITOR=cat git merge --continue
done <$series_list
test -n "$only_merge" && exit

# Configure
~/g/git.meta/config.mak.sh --prefix /home/avar/local

# Compile
make -j $(nproc) all check-docs
make -j $(nproc) man
test -n "$only_compile" && exit

# Test sanity
make -C t test-lint

# Remove any past test state
make -C t clean
GIT_PROVE_OPTS="--state=save --jobs=$(nproc) --timer"
export GIT_PROVE_OPTS

# First run a smaller subset of tests, likelier to have failures:
git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests
tr '\n' ' ' </tmp/git.build-tests >/tmp/git.build-tests.tr
(
	cd t
	if ! GIT_TEST_HTTPD=1 make T="$(cat /tmp/git.build-tests.tr)" GIT_PROVE_OPTS="$GIT_PROVE_OPTS"
	then
		suggest_bisect
	fi
)
test -n "$only_basic_test" && exit

# Run all tests
(
	cd t
	make clean-except-prove-cache
	if ! GIT_TEST_HTTPD=1 GIT_TEST_DEFAULT_HASH=sha256 make GIT_PROVE_OPTS="$GIT_PROVE_OPTS --exec /bin/bash"
	then
		suggest_bisect
	fi
)
test -n "$only_test" && exit

# Install it
new_version=$(git rev-parse HEAD)
new_tagname=$(tag_name)
new_tag=$(tag_it "$new_version" "$new_tagname")
last_version=$(git rev-parse avar/private)
make -j $(nproc) install install-man
show_built_from

# Post-install & report
echo "Range-diff between last built and what I've got now:"
git --no-pager range-diff --left-only avar/private...

echo "Shortlog from @{u}..:"
git --no-pager shortlog @{u}..

git push avar HEAD:private -f
git push avar $new_tag:refs/built-tags/$new_tagname

echo "Check out the CI result at:"
echo "  https://github.com/avar/git/commit/$new_version"

# Cleanup
rm -rf /tmp/avargit-*
