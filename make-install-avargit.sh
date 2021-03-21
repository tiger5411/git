#!/bin/sh
set -e
set -x

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
        git reset --hard @{u}
        git merge --abort || :
        git reset --hard @{u}
}

show_built_from
reset_it
git checkout build-master || git checkout -b build-master -t origin/master

# TODO:
#   make-dot-not-HEAD-warn-3
#   avar/object-api-to-no-string-argument (TODO: handle -t "some garbage" case)
#   unconditional-abbrev-redo-2021-rebase
# Ejected:
#   avar/fix-tree-mode-fsck (in favor of avar/tree-walk-api-refactor)
#
# If we've got a previous resolution, the merge --continue will
# continue the merge. TODO: make it support --no-edit
for series in \
    avar/fsck-doc \
    avar/makefile-objs-targets-3 \
    avar/fsck-h-interface-5 \
    avar/t4018-diff-hunk-header-regex-tests-3 \
    avar/diff-W-context-2 \
    avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-v2.31.0 \
    avar/commit-graph-usage \
    avar/pcre2-memory-allocation-fixes-2 \
    avar/worktree-add-orphan \
    avar/use-tagOpt-not-tagopt \
    avar/describe-test-refactoring-2 \
    avar/fix-coccicheck-4 \
    avar/object-is-type-error-refactor-2 \
    avar/nuke-read-tree-api-5 \
    avar/tree-walk-api-refactor-4 \
    avar/tree-walk-api-canon-mode-switch \
    pr-git-973/newren/ort-remainder-v1 \
    avar/makefile-rename-git-binary-not-in-place \
    avar/mktag-broken-and-chain-typo \
    avar/support-test-verbose-under-prove-2 \
    avar/support-test-verbose-under-prove-2-for-avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-v2.31.0 \
    avar/sh-remove-sha1-variables \
    avar/test-lib-bail-out-on-accidental-prove-invocation \
    avar/diff-no-index-tests
do
	git merge --no-edit $series || EDITOR=cat git merge --continue
done

make_it() {
	time make -j $(nproc) \
		USE_LIBPCRE=Y \
                LIBPCREDIR=$HOME/g/pcre2/inst \
                CFLAGS="-O0 -g" \
                DEVELOPER=1 \
                prefix=/home/avar/local \
                $@
}

# First run a smaller subset of tests, likelier to have failures:
git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests

# Compile
make_it all man

# Run all tests
(cd t && prove --exec /bin/sh -j $(nproc) $(cat /tmp/git.build-tests))
(cd t && GIT_TEST_DEFAULT_HASH=sha256 prove --exec /bin/bash -j $(nproc) t[0-9]*.sh)

# Install it
new_version=$(git rev-parse HEAD)
new_tagname=$(tag_name)
new_tag=$(tag_it "$new_version" "$new_tagname")
last_version=$(git rev-parse avar/private)
make_it install install-man
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
