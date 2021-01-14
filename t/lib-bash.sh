# Shell library sourced instead of ./test-lib.sh by tests that need
# to run under Bash; primarily intended for tests of the completion
# script.

. ./lib-bash-detection.sh

if test -n "$TEST_SH_IS_BIN_BASH"
then
	# we are in full-on bash mode
	true
elif type bash >/dev/null 2>&1
then
	# execute in full-on bash mode
	unset POSIXLY_CORRECT
	exec bash "$0" "$@"
else
	echo '1..0 #SKIP skipping bash completion tests; bash not available'
	exit 0
fi

. ./test-lib.sh
