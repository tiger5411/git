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

# Doesn't exist anymore. See my 0f50c8e32c8 (Makefile: remove the
# NO_R_TO_GCC_LINKER flag, 2019-05-17), but still needed to build old
# versions due to the LIBPCREDIR below.
NO_R_TO_GCC_LINKER = for-pre-2.23.0-only

# Can safely test 'make install'
prefix=$prefix

# Better installation
INSTALL_SYMLINKS=Y
NO_INSTALL_HARDLINKS=Y

# Dashed built-ins make 'make all' verbose
SKIP_DASHED_BUILT_INS=Y

# Likewise, a more minimal build and install
NO_TCLTK=Y

# PCRE
USE_LIBPCRE=Y
LIBPCREDIR=\$(HOME)/g/pcre2/inst

# t/Makefile
id_u := \$(shell id -u)
GIT_TEST_OPTS = 
GIT_TEST_OPTS += "--root=/run/user/\$(id_u)/git"
GIT_TEST_OPTS += "--verbose-log"

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
