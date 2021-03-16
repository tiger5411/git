# Core flags
CFLAGS=-O0 -g
DEVELOPER=1
#DEVOPTS=no-error

# Can safely test 'make install'
prefix=/tmp/git

# Dashed built-ins make 'make all' verbose
SKIP_DASHED_BUILT_INS=Y

# Likewise, a more minimal build and install
NO_TCLTK=Y

# PCRE
USE_LIBPCRE=Y
LIBPCREDIR=$(HOME)/g/pcre2/inst

# t/Makefile
id_u := $(shell id -u)
GIT_TEST_OPTS="--root=/run/user/$(id_u)/git"
GIT_PROVE_OPTS=--jobs 8 --timer
DEFAULT_TEST_TARGET=prove

