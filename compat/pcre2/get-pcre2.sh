#!/bin/sh -e

# Usage:
# ./get-pcre2.sh '' 'trunk'
# ./get-pcre2.sh '' 'tags/pcre2-10.23'
# ./get-pcre2.sh ~/g/pcre2 ''

srcdir=$1
version=$2
if test -z "$version"
then
	version="tags/pcre2-10.23"
fi

echo Getting PCRE v2 version $version
rm -rfv src
mkdir src src/sljit

for srcfile in \
	pcre2.h \
	pcre2_internal.h \
	pcre2_intmodedep.h \
	pcre2_ucp.h \
	pcre2_auto_possess.c \
	pcre2_chartables.c.dist \
	pcre2_compile.c \
	pcre2_config.c \
	pcre2_context.c \
	pcre2_convert.c \
	pcre2_error.c \
	pcre2_find_bracket.c \
	pcre2_jit_compile.c \
	pcre2_jit_match.c \
	pcre2_jit_misc.c \
	pcre2_maketables.c \
	pcre2_match.c \
	pcre2_match_data.c \
	pcre2_newline.c \
	pcre2_ord2utf.c \
	pcre2_string_utils.c \
	pcre2_study.c \
	pcre2_tables.c \
	pcre2_ucd.c \
	pcre2_valid_utf.c \
	pcre2_xclass.c
do
	if test -z "$srcdir"
	then
		svn cat svn://vcs.exim.org/pcre2/code/$version/src/$srcfile >src/$srcfile
	else
		cp "$srcdir/src/$srcfile" src/$srcfile
	fi
	wc -l src/$srcfile
done

(cd src && ln -sf pcre2_chartables.c.dist pcre2_chartables.c)

if test -z "$srcdir"
then
	for srcfile in $(svn ls svn://vcs.exim.org/pcre2/code/tags/pcre2-10.23/src/sljit)
	do
		svn cat svn://vcs.exim.org/pcre2/code/$version/src/sljit/$srcfile >src/sljit/$srcfile
		wc -l src/sljit/$srcfile
	done
else
	cp -R "$srcdir/src/sljit" src/
	wc -l src/sljit/*
fi
