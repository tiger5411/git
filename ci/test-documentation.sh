#!/usr/bin/env bash
#
# Perform sanity checks on documentation and build it.
#

. ${0%/*}/lib.sh

filter_log () {
	sed -e '/^GIT_VERSION = /d' \
	    -e "/constant Gem::ConfigMap is deprecated/d" \
	    -e '/^    \* new asciidoc flags$/d' \
	    -e '/stripped namespace before processing/d' \
	    -e '/Attributed.*IDs for element/d' \
	    "$1"
}

make $MAKE_TARGETS > >(tee stdout.log) 2> >(tee stderr.raw >&2)
cat stderr.raw
filter_log stderr.raw >stderr.log
test ! -s stderr.log

rm -f stdout.log stderr.log stderr.raw

case $jobname in
doc-asciidoc)
	test -s Documentation/git.html
	test -s Documentation/git.xml
	test -s Documentation/git.1
	grep '<meta name="generator" content="AsciiDoc ' Documentation/git.html
	;;
doc-asciidoctor)
	test -s Documentation/git.html
	grep '<meta name="generator" content="Asciidoctor ' Documentation/git.html
	;;
*)
	exit 1
	;;
esac
