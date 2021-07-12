#include "cache.h"
#include "hook.h"
#include "run-command.h"
#include "hook-list.h"
#include "config.h"

static void free_hook(struct hook *ptr)
{
	if (ptr) {
		free(ptr->feed_pipe_cb_data);
	}
	free(ptr);
}

/*
 * Walks the linked list at 'head' to check if any hook running 'command'
 * already exists. Returns a pointer to that hook if so, otherwise returns NULL.
 */
static struct hook *find_hook_by_command(struct list_head *head,
					 const char *command)
{
	struct list_head *pos = NULL, *tmp = NULL;
	struct hook *found = NULL;

	list_for_each_safe(pos, tmp, head) {
		struct hook *it = list_entry(pos, struct hook, list);
		if (!strcmp(it->command, command)) {
			list_del(pos);
			found = it;
			break;
		}
	}
	return found;
}

/*
 * Adds a hook if it's not already in the list, or moves it to the tail of the
 * list if it was already there.
 * Returns a handle to the hook in case more modification is needed. Do not free
 * the returned handle.
 */
static struct hook *append_or_move_hook(struct list_head *head, const char *command)
{
	/* check if the hook is already in the list */
	struct hook *to_add = find_hook_by_command(head, command);

	if (!to_add) {
		/* adding a new hook, not moving an old one */
		to_add = xmalloc(sizeof(*to_add));
		to_add->command = command;
		to_add->feed_pipe_cb_data = NULL;
		/* This gets overwritten in hook_list() for hookdir hooks. */
		to_add->from_hookdir = 0;
	}

	list_add_tail(&to_add->list, head);

	return to_add;
}

static void remove_hook(struct list_head *to_remove)
{
	struct hook *hook_to_remove = list_entry(to_remove, struct hook, list);
	list_del(to_remove);
	free_hook(hook_to_remove);
}

void clear_hook_list(struct list_head *head)
{
	struct list_head *pos, *tmp;
	list_for_each_safe(pos, tmp, head)
		remove_hook(pos);
}

static int known_hook(const char *name)
{
	const char **p;
	size_t len = strlen(name);
	static int test_hooks_ok = -1;

	for (p = hook_name_list; *p; p++) {
		const char *hook = *p;

		if (!strncmp(name, hook, len) && hook[len] == '\0')
			return 1;
	}

	if (test_hooks_ok == -1)
		test_hooks_ok = git_env_bool("GIT_TEST_FAKE_HOOKS", 0);

	if (test_hooks_ok &&
	    (!strcmp(name, "test-hook") ||
	     !strcmp(name, "does-not-exist")))
		return 1;

	return 0;
}

const char *find_hook(const char *name)
{
	const char *hook_path;

	if (!known_hook(name))
		die(_("the hook '%s' is not known to git, should be in hook-list.h via githooks(5)"),
		    name);

	hook_path = find_hook_gently(name);

	return hook_path;
}

const char *find_hook_gently(const char *name)
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

int hook_exists(const char *name)
{
	return !!find_hook(name);
}

struct hook_config_cb
{
	struct strbuf *hook_key;
	struct list_head *list;
};

/*
 * Callback for git_config which adds configured hooks to a hook list.
 * Hooks can be configured by specifying hook.<name>.command, for example,
 * hook.pre-commit.command = echo "pre-commit hook!"
 */
static int hook_config_lookup(const char *key, const char *value, void *cb_data)
{
	struct hook_config_cb *data = cb_data;
	const char *hook_key = data->hook_key->buf;
	struct list_head *head = data->list;

	if (!strcmp(key, hook_key)) {
		const char *command = value;
		struct strbuf hookcmd_name = STRBUF_INIT;

		if (!command)
			BUG("git_config_get_value overwrote a string it shouldn't have");

		append_or_move_hook(head, command);

		strbuf_release(&hookcmd_name);
	}

	return 0;
}

struct list_head* hook_list(const char* hookname, int allow_unknown)
{
	struct list_head *hook_head = xmalloc(sizeof(struct list_head));
	struct strbuf hook_key = STRBUF_INIT;
	struct hook_config_cb cb_data = {
		.hook_key = &hook_key,
		.list = hook_head
	};

	INIT_LIST_HEAD(hook_head);

	if (!hookname)
		return NULL;

	/* Add the hooks from the config, e.g. hook.pre-commit.command */
	strbuf_addf(&hook_key, "hook.%s.command", hookname);
	git_config(hook_config_lookup, &cb_data);

	if (have_git_dir()) {
		const char *hook_path;
		if (allow_unknown)
			hook_path = find_hook_gently(hookname);
		else
			hook_path = find_hook(hookname);

		/* Add the hook from the hookdir */
		if (hook_path)
			append_or_move_hook(hook_head, hook_path)->from_hookdir = 1;
	}

	return hook_head;
}

void run_hooks_opt_clear(struct run_hooks_opt *o)
{
	strvec_clear(&o->env);
	strvec_clear(&o->args);
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
	cp->env = hook_cb->options->env.v;
	cp->stdout_to_stderr = 1;
	cp->trace2_hook_name = hook_cb->hook_name;
	cp->dir = hook_cb->options->dir;

	/* to enable oneliners, let config-specified hooks run in shell */
	cp->use_shell = !run_me->from_hookdir;

	/* add command */
	if (run_me->from_hookdir && hook_cb->options->absolute_path)
		strvec_push(&cp->args, absolute_path(run_me->command));
	else
		strvec_push(&cp->args, run_me->command);

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
	struct hook *attempted = pp_task_cp;

	hook_cb->rc |= 1;

	strbuf_addf(out, _("Couldn't start hook '%s'\n"),
		    attempted->command);

	return 1;
}

static int notify_hook_finished(int result,
				struct strbuf *out,
				void *pp_cb,
				void *pp_task_cb)
{
	struct hook_cb_data *hook_cb = pp_cb;

	hook_cb->rc |= result;

	if (hook_cb->invoked_hook)
		*hook_cb->invoked_hook = 1;

	/* TODO: if halt-on-error is desired, return 'result' instead. */
	return 0;
}

/*
 * Determines how many jobs to use after we know we want to parallelize. First
 * priority is the config 'hook.jobs' and second priority is the number of CPUs.
 */
static int configured_hook_jobs(void)
{
	/*
	 * The config and the CPU count probably won't change during the process
	 * lifetime, so cache the result in case we invoke multiple hooks during
	 * one process.
	 */
	static int jobs = 0;
	if (jobs)
		return jobs;

	if (git_config_get_int("hook.jobs", &jobs))
		/* if the config isn't set, fall back to CPU count. */
		jobs = online_cpus();

	return jobs;
}

int run_hooks(const char *hook_name, struct list_head *hooks,
	      struct run_hooks_opt *options)
{
	struct hook_cb_data cb_data = {
		.rc = 0,
		.hook_name = hook_name,
		.options = options,
		.invoked_hook = options->invoked_hook,
	};
	int jobs = 1;

	if (!options)
		BUG("a struct run_hooks_opt must be provided to run_hooks");

	cb_data.head = hooks;
	cb_data.run_me = list_first_entry(hooks, struct hook, list);

	/* INIT_ASYNC sets jobs to 0, so go look up how many to use. */
	if (!options->jobs)
		options->jobs = configured_hook_jobs();

	run_processes_parallel_tr2(jobs,
				   pick_next_hook,
				   notify_start_failure,
				   options->feed_pipe,
				   options->consume_sideband,
				   notify_hook_finished,
				   &cb_data,
				   "hook",
				   hook_name);
	return cb_data.rc;
}

int run_hooks_oneshot(const char *hook_name, struct run_hooks_opt *options)
{
	struct list_head *hooks;
	int ret;
	struct run_hooks_opt hook_opt_scratch = RUN_HOOKS_OPT_INIT_SYNC;

	if (!options)
		options = &hook_opt_scratch;

	if (options->path_to_stdin && options->feed_pipe)
		BUG("choose only one method to populate stdin");

	/*
	 * 'git hooks run <hookname>' uses run_found_hooks, so we don't need to
	 * allow unknown hooknames here.
	 */
	hooks = hook_list(hook_name, 0);

	/*
	 * If you need to act on a missing hook, use run_found_hooks()
	 * instead
	 */
	if (list_empty(hooks)) {
		ret = 0;
		goto cleanup;
	}

	ret = run_hooks(hook_name, hooks, options);

cleanup:
	clear_hook_list(hooks);
	run_hooks_opt_clear(options);
	return ret;
}
