#ifndef HOOK_H
#define HOOK_H
#include "strbuf.h"
#include "strvec.h"
#include "run-command.h"

struct hook {
	/* The path to the hook */
	const char *hook_path;
};

struct run_hooks_opt
{
	/* Environment vars to be set for each hook */
	struct strvec env;

	/* Args to be passed to each hook */
	struct strvec args;

	/* Number of threads to parallelize across */
	int jobs;

	/* Resolve and run the "absolute_path(hook)" instead of
	 * "hook". Used for "git worktree" hooks
	 */
	int absolute_path;

	/* Path to initial working directory for subprocess */
	const char *dir;

	/* Path to file which should be piped to stdin for each hook */
	const char *path_to_stdin;
};

#define RUN_HOOKS_OPT_INIT { \
	.jobs = 1, \
	.env = STRVEC_INIT, \
	.args = STRVEC_INIT, \
}

/*
 * Callback provided to feed_pipe_fn and consume_sideband_fn.
 */
struct hook_cb_data {
	int rc;
	const char *hook_name;
	struct hook *run_me;
	struct run_hooks_opt *options;
};

/*
 * Returns the path to the hook file, or NULL if the hook is missing
 * or disabled. Note that this points to static storage that will be
 * overwritten by further calls to find_hook and run_hook_*.
 */
const char *find_hook(const char *name);

/*
 * A boolean version of find_hook()
 */
int hook_exists(const char *hookname);

void run_hooks_opt_clear(struct run_hooks_opt *o);

/*
 * Provides a linked list of 'struct hook' detailing commands which should run
 * in response to the 'hookname' event, in execution order.
 */
struct list_head* hook_list(const char *hookname);

/*
 * Calls find_hook(hookname) and runs the hooks (if any) with
 * run_found_hooks().
 */
int run_hooks(const char *hook_name, struct run_hooks_opt *options);

/*
 * Takes an already resolved hook and runs it. Internally the simpler
 * run_hooks() will call this.
 */
int run_found_hooks(const char *hookname, const char *hook_path,
		    struct run_hooks_opt *options);

/* Empties the list at 'head', calling 'free_hook()' on each entry */
void clear_hook_list(struct list_head *head);
#endif
