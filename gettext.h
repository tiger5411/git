#ifndef GETTEXT_H
#define GETTEXT_H

#ifdef NO_GETTEXT
static inline void git_setup_gettext(void) {}
#else
extern void git_setup_gettext(void);
#endif

#define N_(s) (s)
#ifdef NO_GETTEXT
#define _(s) (s)
#else
#ifndef GETTEXT_POISON
#include <libintl.h>
#define _(s) gettext(s)
#else
char *gettext_poison(const char *);
#define _(s) gettext_poison(s)
#endif
#endif

#endif
