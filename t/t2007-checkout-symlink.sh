#!/bin/sh
#
# Copyright (c) 2007 Junio C Hamano

test_description='git checkout to switch between branches with symlink<->dir'

. ./test-lib.sh

if test "$no_symlinks"
then
    say 'Symbolic links not supported, skipping tests.'
    test_done
    exit
fi

test_expect_success setup '

	mkdir frotz &&
	echo hello >frotz/filfre &&
	git add frotz/filfre &&
	test_tick &&
	git commit -m "master has file frotz/filfre" &&

	git branch side &&

	echo goodbye >nitfol &&
	git add nitfol
	test_tick &&
	git commit -m "master adds file nitfol" &&

	git checkout side &&

	git rm --cached frotz/filfre &&
	mv frotz xyzzy &&
	ln -s xyzzy frotz &&
	git add xyzzy/filfre frotz &&
	test_tick &&
	git commit -m "side moves frotz/ to xyzzy/ and adds frotz->xyzzy/"

'

test_expect_success 'switch from symlink to dir' '

	git checkout master

'

rm -fr frotz xyzzy nitfol &&
git checkout -f master || exit

test_expect_success 'switch from dir to symlink' '

	git checkout side

'

test_done
