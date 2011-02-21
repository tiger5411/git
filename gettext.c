/*
 * Copyright (c) 2010 Ævar Arnfjörð Bjarmason
 */

#include "git-compat-util.h"
#include "gettext.h"

#ifndef NO_GETTEXT
#include <locale.h>
#include <libintl.h>
#ifdef HAVE_LIBCHARSET_H
# include <libcharset.h>
#else
# include <langinfo.h>
# define locale_charset() nl_langinfo(CODESET)
#endif
#endif

int use_gettext_poison(void)
{
	static int poison_requested = -1;
	if (poison_requested == -1)
		poison_requested = getenv("GIT_GETTEXT_POISON") ? 1 : 0;
	return poison_requested;
}

static char rot13_ch(char ch)
{
	/* NEEDSWORK: arbitrary */
	if (ch >= 'a' && ch <= 'z')
		return (ch - 'a' + 13) % 26 + 'a';
	if (ch >= 'A' && ch <= 'Z')
		return (ch - 'A' + 13) % 26 + 'A';
	switch (ch) {
	case '!': return '1';
	case '1': return '!';
	case '@': return '2';
	case '2': return '@';
	case '#': return '3';
	case '3': return '#';
	case '$': return '4';
	case '4': return '$';
	case '%': return '5';
	case '5': return '"';	/* avoid printf magic. */
	case '^': return '6';
	case '6': return '^';
	case '&': return '7';
	case '7': return '&';
	case '*': return '8';
	case '8': return '*';
	case '(': return '9';
	case '9': return '(';
	case ')': return '0';
	case '0': return ')';
	}
	return ch;
}

const char *rot13(const char *msg)
{
	/* NEEDSWORK: leaky */
	char *result = xmallocz(strlen(msg));
	const char *p = msg;
	char *q = result;

	while (*p)
		*q++ = rot13_ch(*p++);
	return result;
}

#ifndef NO_GETTEXT
static void init_gettext_charset(const char *domain)
{
	const char *charset;

	setlocale(LC_CTYPE, "");
	charset = locale_charset();
	bind_textdomain_codeset(domain, charset);
	setlocale(LC_CTYPE, "C");
}

void git_setup_gettext(void)
{
	const char *podir = getenv("GIT_TEXTDOMAINDIR");

	if (!podir)
		podir = GIT_LOCALE_PATH;
	bindtextdomain("git", podir);
	setlocale(LC_MESSAGES, "");
	init_gettext_charset("git");
	textdomain("git");
}
#endif
