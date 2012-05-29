#!/bin/sh

INSTALLED_ASCIIDOC_VERSION=$(asciidoc --version | sed 's/^asciidoc //; s/\.//g')
NEEDED_ASCIIDOC_VERSION=841

if test $INSTALLED_ASCIIDOC_VERSION -ge $NEEDED_ASCIIDOC_VERSION
then
	asciidoc $@
else
	../contrib/asciidoc.py $@
fi
