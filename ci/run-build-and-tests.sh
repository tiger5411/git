#!/bin/sh
#
# Build and test Git
#

. ${0%/*}/lib.sh

if test -z "$MAKE_TARGETS"
then
	export MAKE_TARGETS="all test"
fi

case "$jobname" in
linux-gcc)
	export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
	;;
linux-TEST-vars)
	export GIT_TEST_SPLIT_INDEX=yes
	export GIT_TEST_MERGE_ALGORITHM=recursive
	export GIT_TEST_FULL_IN_PACK_ARRAY=true
	export GIT_TEST_OE_SIZE=10
	export GIT_TEST_OE_DELTA_SIZE=5
	export GIT_TEST_COMMIT_GRAPH=1
	export GIT_TEST_COMMIT_GRAPH_CHANGED_PATHS=1
	export GIT_TEST_MULTI_PACK_INDEX=1
	export GIT_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=1
	export GIT_TEST_ADD_I_USE_BUILTIN=1
	export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=master
	export GIT_TEST_WRITE_REV_INDEX=1
	export GIT_TEST_CHECKOUT_WORKERS=2
	;;
linux-clang)
	export GIT_TEST_DEFAULT_HASH=sha1
	;;
linux-sha256)
	export GIT_TEST_DEFAULT_HASH=sha256
	;;
pedantic)
	export DEVOPTS=pedantic
	export MAKE_TARGETS=all
	;;
linux-gcc-4.8)
	export MAKE_TARGETS=all
	;;
esac

case "$MAKE_TARGETS" in
*test*)
	case "$CI_OS_NAME" in
	windows*) cmd //c mklink //j t\\.prove "$(cygpath -aw "$cache_dir/.prove")";;
	*)
		ln -s "$cache_dir/.prove" t/.prove
		if ! test -s t/.prove
		then
			make -C t mock-.prove >/dev/null || :
		fi
	esac
	;;
esac

# For jobs we skip "make test", since we're only interested in
# checking whether we could compile with those settings.
make $MAKE_TARGETS

check_unignored_build_artifacts

save_good_tree
