#include "exec_cmd.h"
#include <locale.h>
#include <libintl.h>
#include <langinfo.h>
#include <stdlib.h>

#ifdef GETTEXT_POISON
#include <stdio.h>
#include <stdlib.h>
char *gettext_poison(const char* msgid)
{
	if (getenv("GIT_GETTEXT_POISON_DEBUG"))
		fprintf(stderr, "msgid = [%s]\n", msgid);
	return "# POISON";
}
#endif

extern void git_setup_gettext(void) {
	char *podir;
	char *envdir = getenv("GIT_TEXTDOMAINDIR");
	char *charset;

	if (envdir) {
		(void)bindtextdomain("git", envdir);
	} else {
		podir = (char *)system_path("share/locale");
		if (!podir) return;
		(void)bindtextdomain("git", podir);
		free(podir);
	}

	(void)setlocale(LC_MESSAGES, "");
	(void)setlocale(LC_CTYPE, "");
	charset = nl_langinfo(CODESET);
	(void)bind_textdomain_codeset("git", charset);
	(void)setlocale(LC_CTYPE, "C");
	(void)textdomain("git");
}
