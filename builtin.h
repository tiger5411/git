#ifndef BUILTIN_H
#define BUILTIN_H

#include "git-compat-util.h"
#include "builtin-list.h"
#include "strbuf.h"
#include "cache.h"
#include "commit.h"

/*
 * builtin API
 * ===========
 *
 * Adding a new built-in
 * ---------------------
 *
 * There are 4 things to do to add a built-in command implementation to
 * Git:
 *
 * . Define the implementation of the built-in command `foo` with
 *   signature:
 *
 *	int cmd_foo(int argc, const char **argv, const char *prefix);
 *
 * . Add the external declaration for the function to `builtin.h`.
 *
 * . Add the command to the `commands[]` table defined in `git.c`.
 *   The entry should look like:
 *
 *	{ "foo", cmd_foo, <options> },
 *
 * where options is the bitwise-or of:
 *
 * `RUN_SETUP`:
 *	If there is not a Git directory to work on, abort.  If there
 *	is a work tree, chdir to the top of it if the command was
 *	invoked in a subdirectory.  If there is no work tree, no
 *	chdir() is done.
 *
 * `RUN_SETUP_GENTLY`:
 *	If there is a Git directory, chdir as per RUN_SETUP, otherwise,
 *	don't chdir anywhere.
 *
 * `USE_PAGER`:
 *
 *	If the standard output is connected to a tty, spawn a pager and
 *	feed our output to it.
 *
 * `NEED_WORK_TREE`:
 *
 *	Make sure there is a work tree, i.e. the command cannot act
 *	on bare repositories.
 *	This only makes sense when `RUN_SETUP` is also set.
 *
 * `SUPPORT_SUPER_PREFIX`:
 *
 *	The built-in supports `--super-prefix`.
 *
 * `DELAY_PAGER_CONFIG`:
 *
 *	If RUN_SETUP or RUN_SETUP_GENTLY is set, git.c normally handles
 *	the `pager.<cmd>`-configuration. If this flag is used, git.c
 *	will skip that step, instead allowing the built-in to make a
 *	more informed decision, e.g., by ignoring `pager.<cmd>` for
 *	certain subcommands.
 *
 * . Add `builtin/foo.o` to `BUILTIN_OBJS` in `Makefile`.
 *
 * Additionally, if `foo` is a new command, there are 4 more things to do:
 *
 * . Add tests to `t/` directory.
 *
 * . Write documentation in `Documentation/git-foo.txt`.
 *
 * . Add an entry for `git-foo` to `command-list.txt`.
 *
 * . Add an entry for `/git-foo` to `.gitignore`.
 *
 *
 * How a built-in is called
 * ------------------------
 *
 * The implementation `cmd_foo()` takes three parameters, `argc`, `argv,
 * and `prefix`.  The first two are similar to what `main()` of a
 * standalone command would be called with.
 *
 * When `RUN_SETUP` is specified in the `commands[]` table, and when you
 * were started from a subdirectory of the work tree, `cmd_foo()` is called
 * after chdir(2) to the top of the work tree, and `prefix` gets the path
 * to the subdirectory the command started from.  This allows you to
 * convert a user-supplied pathname (typically relative to that directory)
 * to a pathname relative to the top of the work tree.
 *
 * The return value from `cmd_foo()` becomes the exit status of the
 * command.
 */

extern const char git_usage_string[];
extern const char git_more_info_string[];

/**
 * If a built-in has DELAY_PAGER_CONFIG set, the built-in should call this early
 * when it wishes to respect the `pager.foo`-config. The `cmd` is the name of
 * the built-in, e.g., "foo". If a paging-choice has already been setup, this
 * does nothing. The default in `def` should be 0 for "pager off", 1 for "pager
 * on" or -1 for "punt".
 *
 * You should most likely use a default of 0 or 1. "Punt" (-1) could be useful
 * to be able to fall back to some historical compatibility name.
 */
void setup_auto_pager(const char *cmd, int def);

int is_builtin(const char *s);

/**
 * builtin-like functions used between different builtin/ *.c files,
 * but not a "real" builtin in the "static struct cmd_struct commands"
 * list in git.c
 */
int cmd_log_reflog(int argc, const char **argv, const char *prefix);

#endif
