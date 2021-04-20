#!/bin/sh
set -e
set -x

no_range_diff=
only_range_diff=
only_merge=
only_compile=
only_basic_test=
only_test=
force_push=
while test $# != 0
do
	case "$1" in
	--no-range-diff)
		no_range_diff=yes
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
	*)
		break
		;;
	esac
	shift
done

meta_dir="$(pwd)"
cd ~/g/git.build

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
	cat "$meta_dir"/"$0" >>$tmp

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
	if ! git rev-parse @{upstream} >/dev/null
	then
		echo No upstream setup for $branch
		exit 1
	fi

	# Is anything else depending on an older version of this?
	# Assume that dependencies come first and make a note of "bad"
	# reverse dependencies (some are legitimate older versions
	# themselves)
	case "$branch" in
	    *-[0-9])
		    base=$(echo "$branch" | sed 's/-[0-9]$//')

		    git config --local --get-regexp '^branch\.[^.]+\.merge' \
			>$series_list.cfg
		    # "-[^0-9]$" to only pick up e.g. "foo-5" and
		    # "foo-4" for a "foo-5", not a "foo-prep" for a
		    # "foo-5".
		    grep " refs/heads/$base-[^0-9]$" $series_list.cfg >$series_list.cfg.base || :
		    if test -s $series_list.cfg.base
		    then
			    grep -v " refs/heads/$branch$" $series_list.cfg.base \
				 >>$series_list.old-merge || :
		    fi
		    ;;
	    *)
		    ;;
	esac

	# Does this branch still depend on an older upstream?
	if grep -q "$branch" $series_list.old-merge
	then
		my_depends="$(git config branch.$branch.merge)"
		echo "$branch depends on $my_depends but a newer version is in this series.conf!"
		exit 1
	fi

	if ! git rev-parse refs/remotes/avar/$branch >/dev/null 2>&1
	then
		echo Pushing missing $branch to avar remote
		git push avar $branch:$branch
	else
		git rev-parse $branch refs/remotes/avar/$branch >$series_list.tmp
		num_sha=$(uniq $series_list.tmp | wc -l)
		if test $num_sha -ne 1
		then
			echo Have $branch and avar/$branch at two different commits:
			cat $series_list.tmp
			if test -z "$force_push"
			then
				# Die if I need to force push, will manually sort it out.
				git push avar $branch:$branch
			else
				git push avar $branch:$branch -f
			fi
		fi
	fi

	upstream=$(git for-each-ref --format="%(upstream)" refs/heads/$branch)

	if echo $upstream | grep -q ^refs/remotes/avar/
	then
		if ! git merge-base --is-ancestor $upstream $branch
		then
			echo $branch needs to be rebased on latest $upstream
			exit 1
		fi
	fi
done <$series_list

# Check what's already merged
while read -r branch
do
	if test -n "$no_range_diff"
	then
		continue
	fi
	git --no-pager range-diff --right-only origin/master...$branch >$series_list.range-diff
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
make -j $(nproc) all man check-docs
test -n "$only_compile" && exit

# First run a smaller subset of tests, likelier to have failures:
git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests
tr '\n' ' ' </tmp/git.build-tests >/tmp/git.build-tests.tr
(
	cd t &&
	GIT_TEST_HTTPD=1 make GIT_PROVE_OPTS="--jobs=$(nproc) --timer" T="$(cat /tmp/git.build-tests.tr)"
)
test -n "$only_basic_test" && exit

# Run all tests
(
	cd t &&
	make -j $(nproc) clean-except-prove-cache &&
	GIT_TEST_HTTPD=1 GIT_TEST_DEFAULT_HASH=sha256 make -j $(nproc) all test-lint GIT_PROVE_OPTS="--exec /bin/bash --jobs=$(nproc) --timer --state=failed,slow,save"
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
