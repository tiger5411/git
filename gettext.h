/*
 * Copyright (c) 2010-2011 Ævar Arnfjörð Bjarmason
 *
 * This is a skeleton no-op implementation of gettext for Git.
 * You can replace it with something that uses libintl.h and wraps
 * gettext() to try out the translations.
 */

#ifndef GETTEXT_H
#define GETTEXT_H

#ifndef NO_GETTEXT
#include <libintl.h>
#else
#	ifdef gettext
#		undef gettext
#	endif
#	define gettext(s) (s)
#endif

#ifdef _
#error "namespace conflict: '_' is pre-defined?"
#endif

#define FORMAT_PRESERVING(n) __attribute__((format_arg(n)))

#ifndef NO_GETTEXT
extern void git_setup_gettext(void);
#else
static inline void git_setup_gettext(void)
{
}
#endif

#ifdef GETTEXT_POISON
extern int use_gettext_poison(void);
extern const char *rot13(const char *msgid);
#else
#define use_gettext_poison() 0
#endif

static inline FORMAT_PRESERVING(1) const char *_(const char *msgid)
{
	return use_gettext_poison() ? rot13(msgid) : gettext(msgid);
}

/* Mark msgid for translation but do not translate it. */
#define N_(msgid) (msgid)

#endif
