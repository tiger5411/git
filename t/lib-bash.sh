# Shell library sourced instead of ./test-lib.sh by tests that need
# to run under Bash; primarily intended for tests of the completion
# script.

if test -n "$BASH"
then
	# we are in full-on bash mode
	true
elif type bash >/dev/null 2>&1
then
	# execute with bash
	exec bash "$0" "$@"
else
	skip_all="bash not available"
fi

. ./test-lib.sh

posix_blurb=
if test -n "$POSIXLY_CORRECT"
then
	posix_blurb=" in POSIXLY_CORRECT mode"
fi

say "# lib-bash.sh: running under $BASH_VERSION$posix_blurb"
