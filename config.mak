USE_LIBPCRE=Y
LIBPCREDIR=$(HOME)/g/pcre2/inst
CFLAGS=-O0 -g
DEVELOPER=1

prefix=/tmp/git
#DEVOPTS=no-error

# t/Makefile
id_u := $(shell id -u)
GIT_TEST_OPTS="--root=/run/user/$(id_u)/git"
GIT_PROVE_OPTS=--jobs 8 --state=save,failed,slow --timer
DEFAULT_TEST_TARGET=prove

