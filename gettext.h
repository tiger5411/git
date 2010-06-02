#ifndef GETTEXT_H
#define GETTEXT_H

void git_setup_gettext(void);

#ifdef NO_GETTEXT
#define _(s) (s)
#else
#include <libintl.h>
#define _(s) gettext(s)
#endif

#endif
