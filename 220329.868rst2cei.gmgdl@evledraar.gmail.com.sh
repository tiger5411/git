#!/bin/sh
set -xe

if ! test -d /tmp/scalar.git
then
	git clone --bare https://github.com/Microsoft/scalar.git /tmp/scalar.git
	mv /tmp/scalar.git/objects/pack/*.pack /tmp/scalar.git/my.pack
fi
git hyperfine \
        --warmup 1 -r 3 \
	-L rev neeraj-v4,avar-RFC \
	-s 'make CFLAGS=-O3 && rm -rf repo && git init repo && cp -R t repo/ && git ls-files -- t >repo/.git/to-add.txt' \
	-p 'rm -rf repo/.git/objects/* repo/.git/index' \
	$@'./git -c core.fsync=loose-object -c core.fsyncMethod=batch -C repo update-index --add --stdin <repo/.git/to-add.txt'

git hyperfine \
        --warmup 1 -r 3 \
	-L rev neeraj-v4,avar-RFC \
	-s 'make CFLAGS=-O3 && rm -rf repo && git init repo && cp -R t repo/' \
	-p 'rm -rf repo/.git/objects/* repo/.git/index' \
	$@'./git -c core.fsync=loose-object -c core.fsyncMethod=batch -C repo add .'

git hyperfine \
        --warmup 1 -r 3 \
	-L rev neeraj-v4,avar-RFC \
        -s 'make CFLAGS=-O3' \
        -p 'git init --bare dest.git' \
        -c 'rm -rf dest.git' \
        $@'./git -C dest.git -c core.fsyncMethod=batch unpack-objects </tmp/scalar.git/my.pack'
