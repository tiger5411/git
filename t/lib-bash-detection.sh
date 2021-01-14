#!/bin/sh

TEST_SH_IS_BIN_BASH=
if test -n "$BASH" && test -z "$POSIXLY_CORRECT"
then
	TEST_SH_IS_BIN_BASH=true
	export TEST_SH_IS_BIN_BASH
fi
