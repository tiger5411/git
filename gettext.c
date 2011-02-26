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

#ifdef GETTEXT_POISON
int use_gettext_poison(void)
{
	static int poison_requested = -1;
	if (poison_requested == -1)
		poison_requested = getenv("GIT_GETTEXT_POISON") ? 1 : 0;
	return poison_requested;
}
#endif

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
