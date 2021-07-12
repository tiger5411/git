#include "cache.h"
#include "hook.h"
#include "run-command.h"
#include "config.h"

/*
 * Walks the linked list at 'head' to check if any hook named 'name'
 * already exists. Returns a pointer to that hook if so, otherwise returns NULL.
 */
static struct hook *find_hook_by_name(struct list_head *head,
					 const char *name)
{
	struct list_head *pos = NULL, *tmp = NULL;
	struct hook *found = NULL;

	list_for_each_safe(pos, tmp, head) {
		struct hook *it = list_entry(pos, struct hook, list);
		if (!strcmp(it->name, name)) {
			list_del(pos);
			found = it;
			break;
		}
	}
	return found;
}

/*
 * Adds a hook if it's not already in the list, or moves it to the tail of the
 * list if it was already there. name == NULL indicates it's from the hookdir;
 * just append it in this case.
 */
static void append_or_move_hook(struct list_head *head, const char *name)
{
	struct hook *to_add = NULL;

	/* if it's not from hookdir, check if the hook is already in the list */
	if (name)
		to_add = find_hook_by_name(head, name);

	if (!to_add) {
		/* adding a new hook, not moving an old one */
		to_add = xcalloc(1, sizeof(*to_add));
		to_add->name = xstrdup_or_null(name);
	}

	list_add_tail(&to_add->list, head);
}

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
	free(hook->name);
	free(hook->feed_pipe_cb_data);
	free(hook);
}

struct hook_config_cb
{
	const char *hook_event;
	struct list_head *list;
};

/*
 * Callback for git_config which adds configured hooks to a hook list.  Hooks
 * can be configured by specifying both hook.<friend-name>.command = <path> and
 * hook.<friendly-name>.event = <hook-event>.
 */
static int hook_config_lookup(const char *key, const char *value, void *cb_data)
{
	struct hook_config_cb *data = cb_data;
	const char *subsection, *parsed_key;
	size_t subsection_len = 0;
	struct strbuf subsection_cpy = STRBUF_INIT;

	/*
	 * Don't bother doing the expensive parse if there's no
	 * chance that the config matches 'hook.myhook.event = hook_event'.
	 */
	if (!value || strcmp(value, data->hook_event))
		return 0;

	/* Looking for "hook.friendlyname.event = hook_event" */
	if (parse_config_key(key,
			    "hook",
			    &subsection,
			    &subsection_len,
			    &parsed_key) ||
	    strcmp(parsed_key, "event"))
		return 0;

	/*
	 * 'subsection' is a pointer to the internals of 'key', which we don't
	 * own the memory for. Copy it away to the hook list.
	 */
	strbuf_add(&subsection_cpy, subsection, subsection_len);

	append_or_move_hook(data->list, subsection_cpy.buf);
	strbuf_release(&subsection_cpy);

	return 0;
}

struct list_head *list_hooks(const char *hookname)
{
	struct list_head *hook_head = xmalloc(sizeof(struct list_head));
	struct hook_config_cb cb_data = {
		.hook_event = hookname,
		.list = hook_head,
	};

	INIT_LIST_HEAD(hook_head);

	if (!hookname)
		BUG("null hookname was provided to hook_list()!");

	/* Add the hooks from the config, e.g. hook.myhook.event = pre-commit */
	git_config(hook_config_lookup, &cb_data);

	/* Add the hook from the hookdir. The placeholder makes it easier to
	 * allocate work in pick_next_hook. */
	if (have_git_dir() && find_hook(hookname))
		append_or_move_hook(hook_head, NULL);

	return hook_head;
}

void clear_hook_list(struct list_head *head)
{
	struct list_head *pos, *tmp;
	list_for_each_safe(pos, tmp, head)
		remove_hook(pos);
	free(head);
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

	if (!run_me)
		return 0;

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

	/*
	 * to enable oneliners, let config-specified hooks run in shell.
	 * config-specified hooks have a name.
	 */
	cp->use_shell = !!run_me->name;

	/* add command */
	if (run_me->name) {
		/* ...from config */
		struct strbuf cmd_key = STRBUF_INIT;
		char *command = NULL;

		strbuf_addf(&cmd_key, "hook.%s.command", run_me->name);
		if (git_config_get_string(cmd_key.buf, &command)) {
			/* TODO test me! */
			die(_("'hook.%s.command' must be configured "
			      "or 'hook.%s.event' must be removed; aborting.\n"),
			    run_me->name, run_me->name);
		}

		strvec_push(&cp->args, command);
		free(command);
		strbuf_release(&cmd_key);
	} else {
		/* ...from hookdir. */
		const char *hook_path = NULL;
		/*
		 * At this point we are already running, so don't validate
		 * whether the hook name is known or not. Validation was
		 * performed earlier in list_hooks().
		 */
		hook_path = find_hook(hook_cb->hook_name);
		if (!hook_path)
			BUG("hookdir hook in hook list but no hookdir hook present in filesystem");

		if (cp->dir && !is_absolute_path(hook_path))
			hook_path = absolute_path(hook_path);

		strvec_push(&cp->args, hook_path);
	}

	/*
	 * add passed-in argv, without expanding - let the user get back
	 * exactly what they put in
	 */
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

	if (run_me->name)
		strbuf_addf(out, _("Couldn't start hook '%s'\n"), run_me->name);
	else
		strbuf_addstr(out, _("Couldn't start hook from hooks directory\n"));

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

static int nr_hook_jobs(struct run_hooks_opt *options)
{
	static int jobs;

	if (!options->parallel)
		return 1;
	if (jobs)
		return jobs;
	if (git_config_get_int("hook.jobs", &jobs))
		jobs = online_cpus();

	return jobs;
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
	int jobs = nr_hook_jobs(options);
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

static int run_hooks_opt_v(const char *hook_name, struct run_hooks_opt *options,
			   va_list ap)
{
	const char *arg;
	va_list cp;

	va_copy(cp, ap);
	while ((arg = va_arg(ap, const char *)))
		strvec_push(&options->args, arg);
	va_end(cp);

	return run_hooks_opt(hook_name, options);
}

int run_hooks_l(const char *hook_name, ...)
{
	struct run_hooks_opt opt = RUN_HOOKS_OPT_INIT;
	va_list ap;
	int ret;

	va_start(ap, hook_name);
	ret = run_hooks_opt_v(hook_name, &opt, ap);
	va_end(ap);

	return ret;
}

int par_hooks_l(const char *hook_name, ...)
{
	struct run_hooks_opt opt = RUN_HOOKS_OPT_INIT_PARALLEL;
	va_list ap;
	int ret;

	va_start(ap, hook_name);
	ret = run_hooks_opt_v(hook_name, &opt, ap);
	va_end(ap);

	return ret;
}
