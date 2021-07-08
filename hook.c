#include "cache.h"
#include "hook.h"
#include "run-command.h"
#include "config.h"

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

		if (err == EACCES && advice_enabled(ADVICE_IGNORED_HOOK)) {
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

static void remove_hook(struct list_head *head)
{
	struct hook *hook = list_entry(head, struct hook, list);
	list_del(head);
	free(hook->feed_pipe_cb_data);
	free(hook);
}

static void clear_hook_list(struct list_head *head)
{
	struct list_head *pos, *tmp;
	list_for_each_safe(pos, tmp, head)
		remove_hook(pos);
	free(head);
}

static struct list_head *list_hooks(const char *hook_name)
{
	struct list_head *hook_head = xmalloc(sizeof(struct list_head));

	INIT_LIST_HEAD(hook_head);

	if (!hook_name)
		BUG("need a hook_name!");

	if (have_git_dir()) {
		const char *hook_path = find_hook(hook_name);

		/* Add the hook from the hookdir */
		if (hook_path) {
			struct hook *to_add = xmalloc(sizeof(*to_add));
			to_add->hook_path = hook_path;
			to_add->feed_pipe_cb_data = NULL;
			list_add_tail(&to_add->list, hook_head);
		}
	}

	return hook_head;
}

int hook_exists(const char *name)
{
	struct list_head *hooks;
	int exists;

	hooks = list_hooks(name);
	exists = !list_empty(hooks);
	clear_hook_list(hooks);

	return exists;
}

int pipe_from_string_list(struct strbuf *pipe, void *pp_cb, void *pp_task_cb)
{
	int *item_idx;
	struct hook *ctx = pp_task_cb;
	struct hook_cb_data *hook_cb = pp_cb;
	struct string_list *to_pipe = hook_cb->options->feed_pipe_ctx;

	/* Bootstrap the state manager if necessary. */
	if (!ctx->feed_pipe_cb_data) {
		ctx->feed_pipe_cb_data = xmalloc(sizeof(unsigned int));
		*(int*)ctx->feed_pipe_cb_data = 0;
	}

	item_idx = ctx->feed_pipe_cb_data;

	if (*item_idx < to_pipe->nr) {
		strbuf_addf(pipe, "%s\n", to_pipe->items[*item_idx].string);
		(*item_idx)++;
		return 0;
	}
	return 1;
}

static int pick_next_hook(struct child_process *cp,
			  struct strbuf *out,
			  void *pp_cb,
			  void **pp_task_cb)
{
	struct hook_cb_data *hook_cb = pp_cb;
	struct hook *run_me = hook_cb->run_me;
	const char *hook_path;

	if (!run_me)
		return 0;
	hook_path = run_me->hook_path;

	strvec_pushv(&cp->env_array, hook_cb->options->env.v);
	/* reopen the file for stdin; run_command closes it. */
	if (hook_cb->options->path_to_stdin) {
		cp->no_stdin = 0;
		cp->in = xopen(hook_cb->options->path_to_stdin, O_RDONLY);
	} else if (hook_cb->options->feed_pipe) {
		/* ask for start_command() to make a pipe for us */
		cp->in = -1;
		cp->no_stdin = 0;
	} else {
		cp->no_stdin = 1;
	}
	cp->stdout_to_stderr = 1;
	cp->trace2_hook_name = hook_cb->hook_name;
	cp->dir = hook_cb->options->dir;

	if (cp->dir && !is_absolute_path(hook_path))
		strvec_push(&cp->args, absolute_path(hook_path));
	else
		strvec_push(&cp->args, hook_path);
	strvec_pushv(&cp->args, hook_cb->options->args.v);

	/* Provide context for errors if necessary */
	*pp_task_cb = run_me;

	/* Get the next entry ready */
	if (hook_cb->run_me->list.next == hook_cb->head)
		hook_cb->run_me = NULL;
	else
		hook_cb->run_me = list_entry(hook_cb->run_me->list.next,
					     struct hook, list);

	return 1;
}

static int notify_start_failure(struct strbuf *out,
				void *pp_cb,
				void *pp_task_cp)
{
	struct hook_cb_data *hook_cb = pp_cb;
	struct hook *run_me = pp_task_cp;

	hook_cb->rc |= 1;

	strbuf_addf(out, _("Couldn't start hook '%s'\n"),
		    run_me->hook_path);

	return 1;
}

static int notify_hook_finished(int result,
				struct strbuf *out,
				void *pp_cb,
				void *pp_task_cb)
{
	struct hook_cb_data *hook_cb = pp_cb;
	struct run_hooks_opt *opt = hook_cb->options;

	hook_cb->rc |= result;

	if (opt->invoked_hook)
		*opt->invoked_hook = 1;

	return 0;
}

static void run_hooks_opt_clear(struct run_hooks_opt *options)
{
	strvec_clear(&options->env);
	strvec_clear(&options->args);
}

int run_hooks_opt(const char *hook_name, struct run_hooks_opt *options)
{
	struct list_head *hooks = list_hooks(hook_name);
	struct strbuf abs_path = STRBUF_INIT;
	struct hook my_hook = { 0 };
	struct hook_cb_data cb_data = {
		.rc = 0,
		.hook_name = hook_name,
		.options = options,
	};
	int jobs = 1;
	int ret = 0;

	if (!options)
		BUG("a struct run_hooks_opt must be provided to run_hooks");

	if (options->invoked_hook)
		*options->invoked_hook = 0;

	if (list_empty(hooks) && !options->error_if_missing)
		goto cleanup;

	if (list_empty(hooks)) {
		ret = error("cannot find a hook named %s", hook_name);
		goto cleanup;
	}

	cb_data.head = hooks;
	cb_data.run_me = list_first_entry(hooks, struct hook, list);

	run_processes_parallel_tr2(jobs,
				   pick_next_hook,
				   notify_start_failure,
				   options->feed_pipe,
				   options->consume_sideband,
				   notify_hook_finished,
				   &cb_data,
				   "hook",
				   hook_name);
	ret = cb_data.rc;
cleanup:
	strbuf_release(&abs_path);
	run_hooks_opt_clear(options);
	free(my_hook.feed_pipe_cb_data);
	clear_hook_list(hooks);
	return ret;
}

int run_hooks(const char *hook_name)
{
	struct run_hooks_opt opt = RUN_HOOKS_OPT_INIT;

	return run_hooks_opt(hook_name, &opt);
}

int run_hooks_l(const char *hook_name, ...)
{
	struct run_hooks_opt opt = RUN_HOOKS_OPT_INIT;
	va_list ap;
	const char *arg;

	va_start(ap, hook_name);
	while ((arg = va_arg(ap, const char *)))
		strvec_push(&opt.args, arg);
	va_end(ap);

	return run_hooks_opt(hook_name, &opt);
}
