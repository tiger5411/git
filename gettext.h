/*
 * Copyright (c) 2010-2011 Ævar Arnfjörð Bjarmason
 *
 * This is a skeleton no-op implementation of gettext for Git.
 * You can replace it with something that uses libintl.h and wraps
 * gettext() to try out the translations.
 */

#ifndef GETTEXT_H
#define GETTEXT_H

#ifdef _
#error "namespace conflict: '_' is pre-defined?"
#endif

#define FORMAT_PRESERVING(n) __attribute__((format_arg(n)))

static inline FORMAT_PRESERVING(1) const char *_(const char *msgid)
{
	return msgid;
}

/* Mark msgid for translation but do not translate it. */
#define N_(msgid) (msgid)

#endif
