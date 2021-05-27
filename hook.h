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

void run_hooks_opt_clear(struct run_hooks_opt *o);

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
#endif
