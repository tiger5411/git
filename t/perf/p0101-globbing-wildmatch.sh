#!/bin/sh

test_description="Tests wildmatch()"

. ./perf-lib.sh

test_perf_large_repo

for pat in \
	'foo' \
	'bar' \
	'' \
	'???' \
	'??' \
	'*' \
	'f*' \
	'*f' \
	'*foo*' \
	'*ob*a*r*' \
	'*ab' \
	'foo\*' \
	'foo\*bar' \
	'f\\oo' \
	'*[al]?' \
	'[ten]' \
	'**[!te]' \
	'**[!ten]' \
	't[a-g]n' \
	't[!a-g]n' \
	't[!a-g]n' \
	't[^a-g]n' \
	'a[]]b' \
	'a[]-]b' \
	'a[]-]b' \
	'a[]-]b' \
	'a[]a-]b' \
	']' ']' \
	'foo*bar' \
	'foo**bar' \
	'foo**bar' \
	'foo/**/bar' \
	'foo/**/**/bar' \
	'foo/**/bar' \
	'foo/**/**/bar' \
	'foo/**/bar' \
	'foo/**/**/bar' \
	'foo?bar' \
	'foo[/]bar' \
	'f[^eiu][^eiu][^eiu][^eiu][^eiu]r' \
	'f[^eiu][^eiu][^eiu][^eiu][^eiu]r' \
	'**/foo' \
	'**/foo' \
	'**/foo' \
	'*/foo' \
	'**/bar*' \
	'**/bar/*' \
	'**/bar/*' \
	'**/bar/**' \
	'**/bar/*' \
	'**/bar/**' \
	'**/bar**' \
	'*/bar/**' \
	'*/bar/**' \
	'**/bar/*/*' \
	'a[c-c]st' \
	'a[c-c]rt' \
	'[!]-]' \
	'[!]-]' \
	'\' \
	'*/\' \
	'*/\\' \
	'foo' \
	'@foo' \
	'@foo' \
	'\[ab]' \
	'[[]ab]' \
	'[[:]ab]' \
	'[[::]ab]' \
	'[[:digit]ab]' \
	'[\[:]ab]' \
	'\??\?b' \
	'\a\b\c' \
	'' \
	'**/t[o]' \
	'[[:alpha:]][[:digit:]][[:upper:]]' \
	'[[:digit:][:upper:][:space:]]' \
	'[[:digit:][:upper:][:space:]]' \
	'[[:digit:][:upper:][:space:]]' \
	'[[:digit:][:upper:][:spaci:]]' \
	'[[:digit:][:upper:][:space:]]' \
	'[[:digit:][:upper:][:space:]]' \
	'[[:digit:][:punct:][:space:]]' \
	'[[:xdigit:]]' \
	'[[:xdigit:]]' \
	'[[:xdigit:]]' \
	'[a-c[:digit:]x-z]' \
	'[a-c[:digit:]x-z]' \
	'[a-c[:digit:]x-z]' \
	'[a-c[:digit:]x-z]'
do
	test_perf "wildmatch($pat)" "
		git ls-files '$pat' >/dev/null || :
	"
done

test_done
