#!/bin/sh
set -e
set -x

cd ~/g/git.build
git checkout master
git reset --hard @{u}

git merge \
    --no-edit \
    avar/test-lib-misc-fixes-2 \
    avar/log-pager-exit-status \
    avar/diff-free-2 \
    avar/fsck-h-interface \
    avar/t4018-diff-hunk-header-regex-tests-2 \
    gitster/jk/rev-list-disk-usage \
    avar/pcre2-fixes-diffcore-pickaxe-pcre-etc-2-on-master \
    avar/commit-graph-usage \
    avar/diff-W-context

time make -j $(parallel --number-of-cores) \
     USE_LIBPCRE=Y \
     LIBPCREDIR=$HOME/g/pcre2/inst \
     CFLAGS="-O0 -g" \
     DEVELOPER=1 \
     prefix=/home/avar/local \
     all man install install-man
