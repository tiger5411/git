#!/bin/sh
#
# Test Git in parallel
#

. ${0%/*}/lib.sh

case "$CI_OS_NAME" in
windows*) cmd //c mklink //j t\\.prove "$(cygpath -aw "$cache_dir/.prove")";;
*) ln -s "$cache_dir/.prove" t/.prove;;
esac

make --quiet -C t T="$(cd t &&
	./helper/test-tool path-utils slice-tests "$1" "$2" t[0-9]*.sh |
	tr '\n' ' ')"

if test 0 = "$1"
then
	make -C contrib/scalar test
fi

check_unignored_build_artifacts
