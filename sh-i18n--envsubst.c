/*
 * sh-i18n--envsubst.c - a stripped-down version of gettext's envsubst(1)
 *
 * Copyright (C) 2010 Ævar Arnfjörð Bjarmason
 *
 * This is a modified version of
 * 67d0871a8c:gettext-runtime/src/envsubst.c from the gettext.git
 * repository. It has been stripped down to only implement the
 * envsubst(1) features that we need in the git-sh-i18n fallbacks.
 *
 * The "Close standard error" part in main() is from
 * 8dac033df0:gnulib-local/lib/closeout.c. The copyright notices for
 * both files are reproduced immediately below.
 */

#include "git-compat-util.h"

/* Substitution of environment variables in shell format strings.
   Copyright (C) 2003-2007 Free Software Foundation, Inc.
   Written by Bruno Haible <bruno@clisp.org>, 2003.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* closeout.c - close standard output and standard error
   Copyright (C) 1998-2007 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* If true, substitution shall be performed on all variables.  */
static unsigned short int all_variables;

static void subst_from_stdin (void);

int
main (int argc, char *argv[])
{
  all_variables = 1;

  if (argc > 1)
	{
	  error ("too many arguments");
	  exit (EXIT_FAILURE);
	}

  subst_from_stdin ();

  /* Close standard error.  This is simpler than fwriteerror_no_ebadf, because
     upon failure we don't need an errno - all we can do at this point is to
     set an exit status.  */
  errno = 0;
  if (ferror (stderr) || fflush (stderr))
    { 
      fclose (stderr);
      exit (EXIT_FAILURE);
    }
  if (fclose (stderr) && errno != EBADF)
    exit (EXIT_FAILURE);

  exit (EXIT_SUCCESS);
}

/* Type describing list of immutable strings,
   implemented using a dynamic array.  */
typedef struct string_list_ty string_list_ty;
struct string_list_ty
{
  const char **item;
  size_t nitems;
  size_t nitems_max;
};

/* Append a single string to the end of a list of strings.  */
static inline void
string_list_append (string_list_ty *slp, const char *s)
{
  /* Grow the list.  */
  if (slp->nitems >= slp->nitems_max)
    {
      size_t nbytes;

      slp->nitems_max = slp->nitems_max * 2 + 4;
      nbytes = slp->nitems_max * sizeof (slp->item[0]);
      slp->item = (const char **) xrealloc (slp->item, nbytes);
    }

  /* Add the string to the end of the list.  */
  slp->item[slp->nitems++] = s;
}

/* Test whether a string list contains a given string.  */
static inline int
string_list_member (const string_list_ty *slp, const char *s)
{
  size_t j;

  for (j = 0; j < slp->nitems; ++j)
    if (strcmp (slp->item[j], s) == 0)
      return 1;
  return 0;
}

/* Test whether a sorted string list contains a given string.  */
static int
sorted_string_list_member (const string_list_ty *slp, const char *s)
{
  size_t j1, j2;

  j1 = 0;
  j2 = slp->nitems;
  if (j2 > 0)
    {
      /* Binary search.  */
      while (j2 - j1 > 1)
	{
	  /* Here we know that if s is in the list, it is at an index j
	     with j1 <= j < j2.  */
	  size_t j = (j1 + j2) >> 1;
	  int result = strcmp (slp->item[j], s);

	  if (result > 0)
	    j2 = j;
	  else if (result == 0)
	    return 1;
	  else
	    j1 = j + 1;
	}
      if (j2 > j1)
	if (strcmp (slp->item[j1], s) == 0)
	  return 1;
    }
  return 0;
}


/* Set of variables on which to perform substitution.
   Used only if !all_variables.  */
static string_list_ty variables_set;

static int
do_getc ()
{
  int c = getc (stdin);

  if (c == EOF)
    {
      if (ferror (stdin))
	error ("error while reading standard input");
    }

  return c;
}

static inline void
do_ungetc (int c)
{
  if (c != EOF)
    ungetc (c, stdin);
}

/* Copies stdin to stdout, performing substitutions.  */
static void
subst_from_stdin ()
{
  static char *buffer;
  static size_t bufmax;
  static size_t buflen;
  int c;

  for (;;)
    {
      c = do_getc ();
      if (c == EOF)
	break;
      /* Look for $VARIABLE or ${VARIABLE}.  */
      if (c == '$')
	{
	  unsigned short int opening_brace = 0;
	  unsigned short int closing_brace = 0;

	  c = do_getc ();
	  if (c == '{')
	    {
	      opening_brace = 1;
	      c = do_getc ();
	    }
	  if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_')
	    {
	      unsigned short int valid;

	      /* Accumulate the VARIABLE in buffer.  */
	      buflen = 0;
	      do
		{
		  if (buflen >= bufmax)
		    {
		      bufmax = 2 * bufmax + 10;
		      buffer = xrealloc (buffer, bufmax);
		    }
		  buffer[buflen++] = c;

		  c = do_getc ();
		}
	      while ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
		     || (c >= '0' && c <= '9') || c == '_');

	      if (opening_brace)
		{
		  if (c == '}')
		    {
		      closing_brace = 1;
		      valid = 1;
		    }
		  else
		    {
		      valid = 0;
		      do_ungetc (c);
		    }
		}
	      else
		{
		  valid = 1;
		  do_ungetc (c);
		}

	      if (valid)
		{
		  /* Terminate the variable in the buffer.  */
		  if (buflen >= bufmax)
		    {
		      bufmax = 2 * bufmax + 10;
		      buffer = xrealloc (buffer, bufmax);
		    }
		  buffer[buflen] = '\0';

		  /* Test whether the variable shall be substituted.  */
		  if (!all_variables
		      && !sorted_string_list_member (&variables_set, buffer))
		    valid = 0;
		}

	      if (valid)
		{
		  /* Substitute the variable's value from the environment.  */
		  const char *env_value = getenv (buffer);

		  if (env_value != NULL)
		    fputs (env_value, stdout);
		}
	      else
		{
		  /* Perform no substitution at all.  Since the buffered input
		     contains no other '$' than at the start, we can just
		     output all the buffered contents.  */
		  putchar ('$');
		  if (opening_brace)
		    putchar ('{');
		  fwrite (buffer, buflen, 1, stdout);
		  if (closing_brace)
		    putchar ('}');
		}
	    }
	  else
	    {
	      do_ungetc (c);
	      putchar ('$');
	      if (opening_brace)
		putchar ('{');
	    }
	}
      else
	putchar (c);
    }
}
