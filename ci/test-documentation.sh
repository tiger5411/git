#!/usr/bin/env bash
#
# Perform sanity checks on documentation and build it.
#

. ${0%/*}/lib.sh

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
