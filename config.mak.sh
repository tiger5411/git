#!/bin/sh
set -e

# System tuning
if test "$(cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor | sort -u)" != "performance"
then
	sudo cpupower frequency-set -g performance
fi

if test -z "$XDG_RUNTIME_DIR"
then
	echo "Must have $XDG_RUNTIME_DIR defined, e.g. XDG_RUNTIME_DIR=/run/user/\$(id -u)/!"
	exit 1
fi

do_release=
prefix=/tmp/git
cc=cc
cflags="-O0 -g"
while test $# != 0
do
	case "$1" in
	    --cc)
		cc="$2"
		shift
		;;
	    --prefix)
		prefix="$2"
		shift
		;;
	    --do-release)
		do_release=1
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

# Support being called without a .git repo, I don't really use this
# for now, but let's be flexible. Maybe I'll test non-checkouts
toplevel=
set +e
toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
set -e
if test -z "$toplevel"
then
	toplevel="$PWD"
fi

# For temporary testing trash, unique so I don't have checkouts
# trampling on each other with parallel tests
trash_dir=
case "$toplevel" in
/run/user/*|/dev/shm/*)
	# Don't need to use another ramdisk if I'm already on a ramdisk
	;;
*)
	toplevel_no_slash=$(echo "$toplevel" | sed -e 's!^/!!; s!/!-!g')
	trash_dir="$XDG_RUNTIME_DIR/tmp/git-trash/$toplevel_no_slash"
	;;
esac

if test -z "$do_release" && test -e ".git"
then
	git_dir=$(/usr/bin/git rev-parse --git-dir)
	# See https://lore.kernel.org/git/87mtr38tvd.fsf@evledraar.gmail.com/
	if ! grep -q "^/version$" "$git_dir"/info/exclude 2>/dev/null
	then
		# Mkdir for worktrees, they don't have "info" pre-created
		mkdir "$git_dir"/info 2>/dev/null &&
		echo /version >>"$git_dir"/info/exclude
	fi
	echo $(/usr/bin/git grep -h -o -P '(?<=^DEF_VER=v).*' 'HEAD:GIT-VERSION-GEN')-dev >"$toplevel"/version
fi

tmp=$(mktemp /tmp/config.mak-XXXXX)
cat >$tmp <<EOF
# CC
CC = ccache $cc

# I use GCC and/or clang, so save myself the auto-probing invocation
# of \$(CC) on "make" invocation
COMPUTE_HEADER_DEPENDENCIES = yes

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
GIT_TEST_OPTS =${trash_dir:+ --root=$trash_dir}
GIT_TEST_OPTS += --verbose-log
ifdef GIT_TEST_OPTS_NO_BIN_WRAPPERS
GIT_TEST_OPTS += --no-bin-wrappers
endif

DEFAULT_TEST_TARGET=prove

## I set these options on individual command-lines, if only there was
## a GIT_PROVE_OPTS_EXTRA...
#GIT_PROVE_OPTS=--jobs 8 --state=failed,slow,save --timer

## The optional "scalar" (MSFT "git-ng") interface
##
## TODO: Commented out the Makefile changes in series.conf
#INSTALL_SCALAR = Y
EOF

if ! diff -u $toplevel/config.mak $tmp 2>/dev/null
then
	cp -v $tmp $toplevel/config.mak
fi
rm $tmp
