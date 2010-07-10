/*
 * Copyright (c) 2010 Ævar Arnfjörð Bjarmason
 */

#include "git-compat-util.h"
#include "gettext.h"
#include <locale.h>
#include <libintl.h>

int use_gettext_poison(void)
{
	static int poison_requested = -1;
	if (poison_requested == -1)
		poison_requested = getenv("GIT_GETTEXT_POISON") ? 1 : 0;
	return poison_requested;
}

#ifndef NO_GETTEXT
void git_setup_gettext(void)
{
	const char *podir = getenv("GIT_TEXTDOMAINDIR");

	if (!podir)
		podir = GIT_LOCALE_PATH;
	bindtextdomain("git", podir);
	setlocale(LC_MESSAGES, "");
	setlocale(LC_CTYPE, "");
	textdomain("git");
}
#endif
