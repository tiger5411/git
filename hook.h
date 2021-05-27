#ifndef HOOK_H
#define HOOK_H
#include "strbuf.h"
#include "strvec.h"
#include "run-command.h"

struct hook {
	/* The path to the hook */
	const char *hook_path;

	/*
	 * Use this to keep state for your feed_pipe_fn if you are using
	 * run_hooks_opt.feed_pipe. Otherwise, do not touch it.
	 */
	void *feed_pipe_cb_data;
};

struct run_hooks_opt
{
	/* Environment vars to be set for each hook */
	struct strvec env;

	/* Args to be passed to each hook */
	struct strvec args;

	/* Emit an error if the hook is missing */
	unsigned int error_if_missing:1;

	/*
	 * Resolve and run the "absolute_path(hook)" instead of
	 * "hook". Used for "git worktree" hooks
	 */
	int absolute_path;

	/* Path to initial working directory for subprocess */
	const char *dir;

	/* Path to file which should be piped to stdin for each hook */
	const char *path_to_stdin;

	/*
	 * Callback and state pointer to ask for more content to pipe to stdin.
	 * Will be called repeatedly, for each hook. See
	 * hook.c:pipe_from_stdin() for an example. Keep per-hook state in
	 * hook.feed_pipe_cb_data (per process). Keep initialization context in
	 * feed_pipe_ctx (shared by all processes).
	 *
	 * See 'pipe_from_string_list()' for info about how to specify a
	 * string_list as the stdin input instead of writing your own handler.
	 */
	feed_pipe_fn feed_pipe;
	void *feed_pipe_ctx;
};

#define RUN_HOOKS_OPT_INIT { \
	.env = STRVEC_INIT, \
	.args = STRVEC_INIT, \
}

struct hook_cb_data {
	/* rc reflects the cumulative failure state */
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

/**
 * A boolean version of find_hook()
 */
int hook_exists(const char *hookname);

/**
 * Clear data from an initialized "struct run_hooks_opt".
 */
void run_hooks_opt_clear(struct run_hooks_opt *options);

/**
 * Takes a `hook_name`, resolves it to a path with find_hook(), and
 * runs the hook for you with the options specified in "struct
 * run_hooks opt". Will call run_hooks_opt_clear() for you.
 *
 * Returns the status code of the run hook, or a negative value on
 * error().
 */
int run_hooks_opt(const char *hook_name, struct run_hooks_opt *options);

/**
 * A wrapper for run_hooks_opt() which provides a dummy "struct
 * run_hooks_opt" initialized with "RUN_HOOKS_OPT_INIT".
 */
int run_hooks(const char *hook_name);

/**
 * Like run_hooks(), a wrapper for run_hooks_opt().
 *
 * This wrapper will call run_hooks() options.args generated from a
 * list of strings provided to this function. The arguments should be
 * a list of `const char *` strings, terminated by a NULL
 * argument. This is like the old run_hook_le() API.
 */
int run_hooksl(const char *hook_name, ...);

/**
 * To specify a 'struct string_list', set 'run_hooks_opt.feed_pipe_ctx' to the
 * string_list and set 'run_hooks_opt.feed_pipe' to pipe_from_string_list().
 * This will pipe each string in the list to stdin, separated by newlines.  (Do
 * not inject your own newlines.)
 */
int pipe_from_string_list(struct strbuf *pipe, void *pp_cb, void *pp_task_cb);

#endif
