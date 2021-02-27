#!/bin/sh
set -e
set -x

cd ~/g/git.build

reset_it() {
        git reset --hard @{u}
        git merge --abort || :
}

reset_it
git checkout build-master || git checkout -b build-master -t origin/master

# If we've got a previous resolution, the merge --continue will
# continue the merge. TODO: make it support --no-edit
git merge \
    --no-edit \
    avar/makefile-objs-targets-3 \
    avar/post-rm-gettext-poison \
    avar/fsck-h-interface \
    avar/t4018-diff-hunk-header-regex-tests-3 \
    avar/diff-W-context-2 \
    gitster/jk/rev-list-disk-usage \
    avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-master \
    avar/commit-graph-usage \
    avar/pcre2-memory-allocation-fixes-2 \
    avar/worktree-add-orphan \
    avar/use-tagOpt-not-tagopt \
    avar/describe-test-refactoring \
    || EDITOR=cat git merge --continue

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
