#!/bin/sh
set -e

prefix=/tmp/git
while test $# != 0
do
	case "$1" in
	    --prefix)
		prefix="$2"
		shift
		;;
	    *)
		break
		;;
	esac
	shift
done

tmp=$(mktemp /tmp/config.mak-XXXXX)
cat >$tmp <<EOF
# Core flags
CFLAGS=-O0 -g
DEVELOPER=1
#DEVOPTS=no-error

# Can safely test 'make install'
prefix=$prefix

# Dashed built-ins make 'make all' verbose
SKIP_DASHED_BUILT_INS=Y

# Likewise, a more minimal build and install
NO_TCLTK=Y

# PCRE
USE_LIBPCRE=Y
LIBPCREDIR=\$(HOME)/g/pcre2/inst

# t/Makefile
id_u := \$(shell id -u)
GIT_TEST_OPTS="--root=/run/user/\$(id_u)/git"

DEFAULT_TEST_TARGET=prove

## I set these options on individual command-lines, if only there was
## a GIT_PROVE_OPTS_EXTRA...
#GIT_PROVE_OPTS=--jobs 8 --state=failed,slow,save --timer
EOF

toplevel=$(git rev-parse --show-toplevel)
if ! diff -u $toplevel/config.mak $tmp
then
    cp -v $tmp $toplevel/config.mak
fi
