#!/bin/sh
set -e

do_release=
prefix=/tmp/git
cflags="-O0 -g"
while test $# != 0
do
	case "$1" in
	    --prefix)
		prefix="$2"
		do_release=1
		shift
		;;
	    --cflags)
		cflags="$2"
		shift
		;;
	    *)
		break
		;;
	esac
	shift
done

toplevel=$(git rev-parse --show-toplevel)
git_dir=$(git rev-parse --absolute-git-dir)

if test -z "$do_release"
then
	# See https://lore.kernel.org/git/87mtr38tvd.fsf@evledraar.gmail.com/
	if ! grep -q ^"$toplevel"/version "$git_dir"/info/exclude
	then
		# Mkdir for worktrees, they don't have "info" pre-created
		mkdir "$git_dir"/info 2>/dev/null &&
		echo /version >>"$git_dir"/info/exclude
	fi
	echo $(git grep -h -o -P '(?<=^DEF_VER=v).*' 'HEAD:GIT-VERSION-GEN')-dev >"$toplevel"/version
fi

tmp=$(mktemp /tmp/config.mak-XXXXX)
cat >$tmp <<EOF
# CC
CC = ccache cc

# Core flags
CFLAGS = $cflags
DEVELOPER=1
#DEVOPTS=no-error

## Have GCC (or Clang) create a dependency graph in the ".depend"
## directories for use in the Makefile
COMPUTE_HEADER_DEPENDENCIES = yes

## Core flags for testing

# SANITIZE=leak

# Doesn't exist anymore. See my 0f50c8e32c8 (Makefile: remove the
# NO_R_TO_GCC_LINKER flag, 2019-05-17), but still needed to build old
# versions due to the LIBPCREDIR below.
NO_R_TO_GCC_LINKER = for-pre-2.23.0-only

# Can safely test 'make install'
prefix=$prefix

# Have --exec-path not be needed
RUNTIME_PREFIX = Y

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

# No gettext makes some things (e.g. send-email) faster & cheaper, but
# it's a less normal config, so might cause CI failures in gettext tests...
#NO_GETTEXT = YesPlease

# t/Makefile
id_u := \$(shell id -u)
GIT_TEST_OPTS = 
GIT_TEST_OPTS += --root=/run/user/\$(id_u)/$(basename $(dirname $(git rev-parse --absolute-git-dir)))
GIT_TEST_OPTS += --verbose-log

DEFAULT_TEST_TARGET=prove

## I set these options on individual command-lines, if only there was
## a GIT_PROVE_OPTS_EXTRA...
#GIT_PROVE_OPTS=--jobs 8 --state=failed,slow,save --timer

## The optional "scalar" (MSFT "git-ng") interface
INSTALL_SCALAR = Y
EOF

if ! diff -u $toplevel/config.mak $tmp
then
	cp -v $tmp $toplevel/config.mak
fi
rm $tmp
