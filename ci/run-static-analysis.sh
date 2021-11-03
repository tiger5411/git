#!/bin/sh
#
# Perform various static code analysis checks
#

. ${0%/*}/lib.sh

dpkg -S /usr/bin/git
apt-cache show git
git grep -P 'foo(?=bar)'
