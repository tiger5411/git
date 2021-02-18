#!/bin/sh
set -e
set -x

cd ~/g/git.build
git checkout build-master || git checkout -b build-master -t origin/master
git merge --abort || :
git reset --hard @{u}

git merge \
    --no-edit \
    avar/makefile-objs-targets-2 \
    avar/log-pager-exit-status \
    avar/post-rm-gettext-poison \
    avar/diff-free-2 \
    avar/test-lib-misc-fixes-2 \
    avar/fsck-h-interface \
    avar/t4018-diff-hunk-header-regex-tests-2 \
    gitster/jk/rev-list-disk-usage \
    avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-master \
    avar/commit-graph-usage \
    avar/diff-W-context \
    avar/pcre2-memory-allocation-fixes-2

make_it() {
	time make -j $(parallel --number-of-cores) \
		USE_LIBPCRE=Y \
                LIBPCREDIR=$HOME/g/pcre2/inst \
                CFLAGS="-O0 -g" \
                DEVELOPER=1 \
                prefix=/home/avar/local \
                $@
}

git diff --diff-filter=ACMR --name-only --relative=t/ -p @{u}.. -- t/t[0-9]*.sh >/tmp/git.build-tests
make_it all man
(cd t && prove -j $(parallel --number-of-cores) $(cat /tmp/git.build-tests))
make_it install install-man
(cd t && prove -j $(parallel --number-of-cores) t[0-9]*.sh)
git --no-pager shortlog @{u}..
