# Library of functions shared by all CI scripts

# Set 'exit on error' for all CI scripts to let the caller know that
# something went wrong.
# Set tracing executed commands, primarily setting environment variables
# and installing dependencies.
set -ex

# Starting assertions
if test -z "$jobname"
then
	echo "must set a CI jobname" >&2
	exit 1
fi

# Helper functions
setenv () {
	varmode=
	case "$1" in
	--*)
		varmode=$1
		shift
		;;
	esac

	key=$1
	val=$2
	shift 2

	eval "export $key=\"$val\""
}

check_unignored_build_artifacts ()
{
	! git ls-files --other --exclude-standard --error-unmatch \
		-- ':/*' 2>/dev/null ||
	{
		echo "$(tput setaf 1)error: found unignored build artifacts$(tput sgr0)"
		false
	}
}

# GitHub Action doesn't set TERM, which is required by tput
setenv TERM ${TERM:-dumb}

# Clear MAKEFLAGS that may come from the outside world.
MAKEFLAGS=

if test "$GITHUB_ACTIONS" = "true"
then
	CI_TYPE=github-actions
	CC="${CC:-gcc}"

	setenv --test GIT_PROVE_OPTS "--timer --jobs 10"
	GIT_TEST_OPTS="--verbose-log -x"
	MAKEFLAGS="$MAKEFLAGS --jobs=10"
	test Windows != "$RUNNER_OS" ||
	GIT_TEST_OPTS="--no-chain-lint --no-bin-wrappers $GIT_TEST_OPTS"

	setenv --test GIT_TEST_OPTS "$GIT_TEST_OPTS"
else
	echo "Could not identify CI type" >&2
	env >&2
	exit 1
fi

setenv --build DEVELOPER 1
setenv --test DEFAULT_TEST_TARGET prove
setenv --test GIT_TEST_CLONE_2GB true
setenv --build SKIP_DASHED_BUILT_INS YesPlease

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
macos-latest)
	if [ "$jobname" = osx-gcc ]
	then
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python3)"
	else
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python2)"
	fi
	;;
esac

case "$jobname" in
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
	setenv --build SANITIZE leak
	setenv --test GIT_TEST_PASSING_SANITIZE_LEAK true
	;;
esac

setenv --all MAKEFLAGS "$MAKEFLAGS CC=${CC:-cc}"
