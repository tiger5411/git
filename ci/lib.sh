#!/bin/sh
set -e

# Helper libraries
. ${0%/*}/lib-ci-type.sh

# Starting assertions
mode=$1
if test -z "$mode"
then
	echo "need a $0 mode, e.g. --build or --test"
	exit 1
fi
echo "CONFIG: mode=$mode" >&2

if test -z "$jobname"
then
	echo "must set a CI jobname" >&2
	exit 1
fi
echo "CONFIG: jobname=$jobname" >&2
echo "CONFIG: runs_on_pool=$runs_on_pool" >&2
echo "CONFIG: GITHUB_ENV=$GITHUB_ENV" >&2

# Helper functions
setenv () {
	skip=
	varmode=
	case "$1" in
	--*)
		if test "$1" != "$mode" && test "$1" != "--all"
		then
			skip=t
		fi
		varmode=$1
		shift
		;;
	esac

	key=$1
	val=$2
	shift 2

	if test -n "$skip"
	then
		echo "SKIP '$key=$val'" >&2
		return 0
	fi

	if test -n "$GITHUB_ENV"
	then
		echo "$key=$val" >>"$GITHUB_ENV"
	else
		# For local debugging. Not used by the GitHub CI
		# itself.
		eval "export $key=\"$val\""
	fi

	echo "SET: '$key=$val'" >&2
}

# Clear variables that may come from the outside world.
CC=
CC_PACKAGE=
MAKEFLAGS=

# Common make and cmake build options
DEVELOPER=1
SKIP_DASHED_BUILT_INS=YesPlease

# Use common options for "make" (cmake in "vs-build" below)
MAKEFLAGS="DEVELOPER=$DEVELOPER SKIP_DASHED_BUILT_INS=$SKIP_DASHED_BUILT_INS"

case "$CI_TYPE" in
github-actions)
	setenv --test GIT_PROVE_OPTS "--timer --jobs 10"
	GIT_TEST_OPTS="--verbose-log -x --github-workflow-markup"
	MAKEFLAGS="$MAKEFLAGS --jobs=10"
	test Windows != "$RUNNER_OS" ||
	GIT_TEST_OPTS="--no-chain-lint --no-bin-wrappers $GIT_TEST_OPTS"

	setenv --test GIT_TEST_OPTS "$GIT_TEST_OPTS"
	;;
*)
	echo "Unhandled CI type: $CI_TYPE" >&2
	exit 1
	;;
esac

setenv --test DEFAULT_TEST_TARGET prove
setenv --test GIT_TEST_CLONE_2GB true

case "$runs_on_pool" in
ubuntu-latest)
	if test "$jobname" = "linux-gcc-default"
	then
		break
	fi

	if [ "$jobname" = linux-gcc ]
	then
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python3"
	else
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python2"
	fi

	setenv --test GIT_TEST_HTTPD true
	;;
esac

case "$jobname" in
windows-build)
	setenv --build NO_PERL NoThanks
	setenv --build ARTIFACTS_DIRECTORY artifacts
	;;
vs-build)
	setenv --build DEVELOPER $DEVELOPER
	setenv --build SKIP_DASHED_BUILT_INS $SKIP_DASHED_BUILT_INS

	setenv --build NO_PERL NoThanks
	setenv --build NO_GETTEXT NoThanks
	setenv --build ARTIFACTS_DIRECTORY artifacts
	setenv --build INCLUDE_DLLS_IN_ARTIFACTS YesPlease
	setenv --build MSVC YesPlease

	setenv --build GIT_CONFIG_COUNT 2
	setenv --build GIT_CONFIG_KEY_0 user.name
	setenv --build GIT_CONFIG_VALUE_0 CI
	setenv --build GIT_CONFIG_KEY_1 user.emailname
	setenv --build GIT_CONFIG_VALUE_1 ci@git
	setenv --build GIT_CONFIG_VALUE_1 ci@git
	;;
vs-test)
	setenv --test NO_SVN_TESTS YesPlease
	;;
linux-gcc)
	CC=gcc
	CC_PACKAGE=gcc-8
	setenv --test GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME main
	;;
linux-gcc-default)
	CC=gcc
	;;
linux-TEST-vars)
	CC=gcc
	CC_PACKAGE=gcc-8
	setenv --test GIT_TEST_SPLIT_INDEX yes
	setenv --test GIT_TEST_MERGE_ALGORITHM recursive
	setenv --test GIT_TEST_FULL_IN_PACK_ARRAY true
	setenv --test GIT_TEST_OE_SIZE 10
	setenv --test GIT_TEST_OE_DELTA_SIZE 5
	setenv --test GIT_TEST_COMMIT_GRAPH 1
	setenv --test GIT_TEST_COMMIT_GRAPH_CHANGED_PATHS 1
	setenv --test GIT_TEST_MULTI_PACK_INDEX 1
	setenv --test GIT_TEST_MULTI_PACK_INDEX_WRITE_BITMAP 1
	setenv --test GIT_TEST_ADD_I_USE_BUILTIN 1
	setenv --test GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME master
	setenv --test GIT_TEST_WRITE_REV_INDEX 1
	setenv --test GIT_TEST_CHECKOUT_WORKERS 2
	;;
osx-gcc)
	MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python3)"
	CC=gcc
	CC_PACKAGE=gcc-9
	;;
osx-clang)
	MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python2)"
	CC=clang
	;;
linux-clang)
	CC=clang
	setenv --test GIT_TEST_DEFAULT_HASH sha1
	;;
linux-sha256)
	CC=clang
	setenv --test GIT_TEST_DEFAULT_HASH sha256
	;;
pedantic)
	CC=gcc
	# Don't run the tests; we only care about whether Git can be
	# built.
	setenv --build DEVOPTS pedantic
	;;
linux32)
	CC=gcc
	;;
linux-musl)
	CC=gcc
	MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python3 USE_LIBPCRE2=Yes"
	MAKEFLAGS="$MAKEFLAGS NO_REGEX=Yes ICONV_OMITS_BOM=Yes"
	MAKEFLAGS="$MAKEFLAGS GIT_TEST_UTF8_LOCALE=C.UTF-8"
	;;
linux-leaks)
	CC=gcc
	setenv --build SANITIZE leak
	setenv --test GIT_TEST_PASSING_SANITIZE_LEAK true
	;;
esac

MAKEFLAGS="$MAKEFLAGS${CC:+ CC=$CC}"
setenv --all MAKEFLAGS "$MAKEFLAGS"
