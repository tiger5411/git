#include "cache.h"
#include "hook.h"
#include "run-command.h"

const char *find_hook(const char *name)
{
	static struct strbuf path = STRBUF_INIT;

	strbuf_reset(&path);
	strbuf_git_path(&path, "hooks/%s", name);
	if (access(path.buf, X_OK) < 0) {
		int err = errno;

#ifdef STRIP_EXTENSION
		strbuf_addstr(&path, STRIP_EXTENSION);
		if (access(path.buf, X_OK) >= 0)
			return path.buf;
		if (errno == EACCES)
			err = errno;
#endif

		if (err == EACCES && advice_ignored_hook) {
			static struct string_list advise_given = STRING_LIST_INIT_DUP;

			if (!string_list_lookup(&advise_given, name)) {
				string_list_insert(&advise_given, name);
				advise(_("The '%s' hook was ignored because "
					 "it's not set as executable.\n"
					 "You can disable this warning with "
					 "`git config advice.ignoredHook false`."),
				       path.buf);
			}
		}
		return NULL;
	}
	return path.buf;
}



void run_hooks_opt_clear(struct run_hooks_opt *o)
{
	strvec_clear(&o->env);
	strvec_clear(&o->args);
}

static int pick_next_hook(struct child_process *cp,
			  struct strbuf *out,
			  void *pp_cb,
			  void **pp_task_cb)
{
	struct hook_cb_data *hook_cb = pp_cb;
	struct hook *run_me = hook_cb->run_me;

	if (!run_me)
		BUG("did we not return 1 in notify_hook_finished?");

	cp->no_stdin = 1;
	cp->env = hook_cb->options->env.v;
	cp->stdout_to_stderr = 1;
	cp->trace2_hook_name = hook_cb->hook_name;

	/* add command */
	strvec_push(&cp->args, run_me->hook_path);

	/*
	 * add passed-in argv, without expanding - let the user get back
	 * exactly what they put in
	 */
	strvec_pushv(&cp->args, hook_cb->options->args.v);

	/* Provide context for errors if necessary */
	*pp_task_cb = run_me;

	return 1;
}

static int notify_start_failure(struct strbuf *out,
				void *pp_cb,
				void *pp_task_cp)
{
	struct hook_cb_data *hook_cb = pp_cb;
	struct hook *attempted = pp_task_cp;

	/* |= rc in cb */
	hook_cb->rc |= 1;

	strbuf_addf(out, _("Couldn't start hook '%s'\n"),
		    attempted->hook_path);

	return 1;
}

static int notify_hook_finished(int result,
				struct strbuf *out,
				void *pp_cb,
				void *pp_task_cb)
{
	struct hook_cb_data *hook_cb = pp_cb;

	/* |= rc in cb */
	hook_cb->rc |= result;

	return 1;
}


int run_found_hooks(const char *hook_name, const char *hook_path,
		    struct run_hooks_opt *options)
{
	struct hook my_hook = {
		.hook_path = hook_path,
	};
	struct hook_cb_data cb_data = {
		.rc = 0,
		.hook_name = hook_name,
		.options = options,
	};
	cb_data.run_me = &my_hook;

	if (options->jobs != 1)
		BUG("we do not handle %d or any other != 1 job number yet", options->jobs);

	run_processes_parallel_tr2(options->jobs,
				   pick_next_hook,
				   notify_start_failure,
				   notify_hook_finished,
				   &cb_data,
				   "hook",
				   hook_name);

	return cb_data.rc;
}

int run_hooks(const char *hook_name, struct run_hooks_opt *options)
{
	const char *hook_path;
	int ret;
	if (!options)
		BUG("a struct run_hooks_opt must be provided to run_hooks");

	hook_path = find_hook(hook_name);

	/* Care about nonexistence? Use run_found_hooks() */
	if (!hook_path)
		return 0;

	ret = run_found_hooks(hook_name, hook_path, options);
	return ret;
}
