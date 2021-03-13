#!/bin/sh
set -e

toplevel=$(git rev-parse --show-toplevel)
if ! diff -u $toplevel/config.mak ~/g/git.meta/config.mak
then
    cp -v ~/g/git.meta/config.mak $toplevel/
fi
