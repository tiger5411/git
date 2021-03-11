#!/bin/sh
set -e
set -x

cd ~/g/git.build

reset_it() {
        git reset --hard @{u}
        git merge --abort || :
        git reset --hard @{u}
}

reset_it
git checkout build-master || git checkout -b build-master -t origin/master

# TODO:
#   make-dot-not-HEAD-warn-3
#   avar/object-api-to-no-string-argument (TODO: handle -t "some garbage" case)
# Ejected:
#   avar/fix-tree-mode-fsck (in favor of avar/tree-walk-api-refactor)
#
# If we've got a previous resolution, the merge --continue will
# continue the merge. TODO: make it support --no-edit
for series in \
    avar/fsck-doc \
    avar/makefile-objs-targets-3 \
    avar/fsck-h-interface-3 \
    avar/t4018-diff-hunk-header-regex-tests-3 \
    avar/diff-W-context-2 \
    gitster/jk/rev-list-disk-usage \
    avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-master \
    avar/commit-graph-usage \
    avar/pcre2-memory-allocation-fixes-2 \
    avar/worktree-add-orphan \
    avar/use-tagOpt-not-tagopt \
    avar/describe-test-refactoring-2 \
    avar/fix-coccicheck-2 \
    avar/object-is-type-error-refactor-2 \
    avar/nuke-read-tree-api-2 \
    avar/tree-walk-api-refactor \
    pr-git-973/newren/ort-remainder-v1 \
    avar/makefile-rename-git-binary-not-in-place \
    avar/mktag-broken-and-chain-typo \
    avar/support-test-verbose-under-prove-2 \
    avar/sh-remove-sha1-variables
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

git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests
make_it all man
(cd t && prove -j $(nproc) $(cat /tmp/git.build-tests))
make_it install install-man
(cd t && prove -j $(nproc) t[0-9]*.sh)
git --no-pager shortlog @{u}..
git push avar HEAD:private -f
