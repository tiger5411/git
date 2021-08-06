#include "cache.h"
#include "advice.h"
#include "advice-config.h"
#include "config.h"
#include "color.h"
#include "help.h"
#include "string-list.h"

static int advice_use_color = -1;
static char advice_colors[][COLOR_MAXLEN] = {
	GIT_COLOR_RESET,
	GIT_COLOR_YELLOW,	/* HINT */
};

enum color_advice {
	ADVICE_COLOR_RESET = 0,
	ADVICE_COLOR_HINT = 1,
};

static int parse_advise_color_slot(const char *slot)
{
	if (!strcasecmp(slot, "reset"))
		return ADVICE_COLOR_RESET;
	if (!strcasecmp(slot, "hint"))
		return ADVICE_COLOR_HINT;
	return -1;
}

static const char *advise_get_color(enum color_advice ix)
{
	if (want_color_stderr(advice_use_color))
		return advice_colors[ix];
	return "";
}

static const char turn_off_instructions[] =
N_("\n"
   "Disable this message with \"git config %s false\"");

static void vadvise(enum advice_type *type, const char *advice, va_list params)
{
	struct strbuf buf = STRBUF_INIT;
	const char *cp, *np;

	strbuf_vaddf(&buf, advice, params);
	if (type) {
		/*
		 * Some messages end with "\n", others not. Let's
		 * normalize them.
		 */
		strbuf_rtrim(&buf);
		strbuf_addstr(&buf, "\n");

		strbuf_addf(&buf, _(turn_off_instructions), advice_setting[*type].key);
	}

	for (cp = buf.buf; *cp; cp = np) {
		int len;

		np = strchrnul(cp, '\n');
		len = np - cp;

		fprintf(stderr,	_("%shint:%s%.*s%s\n"),
			advise_get_color(ADVICE_COLOR_HINT),
			len ? " " : "",
			len, cp,
			advise_get_color(ADVICE_COLOR_RESET));
		if (*np)
			np++;
	}
	strbuf_release(&buf);
}

void advise(enum advice_type type, const char *advice, ...)
{
	va_list params;
	va_start(params, advice);
	vadvise(&type, advice, params);
	va_end(params);
}

int advice_enabled(enum advice_type type)
{
	return !advice_setting[type].disabled;
}

void advise_if_enabled(enum advice_type type, const char *advice, ...)
{
	va_list params;

	if (!advice_enabled(type))
		return;

	va_start(params, advice);
	vadvise(&type, advice, params);
	va_end(params);
}

int git_default_advice_config(const char *var, const char *value)
{
	const char *slot_name;
	int i;

	if (!strcmp(var, "color.advice")) {
		advice_use_color = git_config_colorbool(var, value);
		return 0;
	}

	if (skip_prefix(var, "color.advice.", &slot_name)) {
		int slot = parse_advise_color_slot(slot_name);
		if (slot < 0)
			return 0;
		if (!value)
			return config_error_nonbool(var);
		return color_parse(value, advice_colors[slot]);
	}

	for (i = 0; i < ARRAY_SIZE(advice_setting); i++) {
		if (strcasecmp(var, advice_setting[i].key))
			continue;
		advice_setting[i].disabled = !git_config_bool(var, value);
		return 0;
	}

	return 0;
}

void list_config_advices(struct string_list *list, const char *prefix)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(advice_setting); i++)
		list_config_item(list, prefix, advice_setting[i].key);
}

int error_resolve_conflict(const char *me)
{
	if (!strcmp(me, "cherry-pick"))
		error(_("Cherry-picking is not possible because you have unmerged files."));
	else if (!strcmp(me, "commit"))
		error(_("Committing is not possible because you have unmerged files."));
	else if (!strcmp(me, "merge"))
		error(_("Merging is not possible because you have unmerged files."));
	else if (!strcmp(me, "pull"))
		error(_("Pulling is not possible because you have unmerged files."));
	else if (!strcmp(me, "revert"))
		error(_("Reverting is not possible because you have unmerged files."));
	else
		error(_("It is not possible to %s because you have unmerged files."),
			me);

	/*
	 * Message used both when 'git commit' fails and when
	 * other commands doing a merge do.
	 */
	advise_if_enabled(ADVICE_RESOLVE_CONFLICT,
			  _("Fix them up in the work tree, and then use 'git add/rm <file>'\n"
			    "as appropriate to mark resolution and make a commit."));
	return -1;
}

void NORETURN die_resolve_conflict(const char *me)
{
	error_resolve_conflict(me);
	die(_("Exiting because of an unresolved conflict."));
}

void NORETURN die_ff_impossible(void)
{
	die(_("Not possible to fast-forward, aborting."));
}

void advise_on_updating_sparse_paths(struct string_list *pathspec_list)
{
	struct string_list_item *item;

	if (!pathspec_list->nr)
		return;

	fprintf(stderr, _("The following paths and/or pathspecs matched paths that exist\n"
			  "outside of your sparse-checkout definition, so will not be\n"
			  "updated in the index:\n"));
	for_each_string_list_item(item, pathspec_list)
		fprintf(stderr, "%s\n", item->string);

	advise_if_enabled(ADVICE_UPDATE_SPARSE_PATH,
			  _("If you intend to update such entries, try one of the following:\n"
			    "* Use the --sparse option.\n"
			    "* Disable or modify the sparsity rules."));
}

void detach_advice(const char *new_name)
{
	const char *fmt =
	_("Switching to '%s'.\n"
	"\n"
	"You are in 'detached HEAD' state. You can look around, make experimental\n"
	"changes and commit them, and you can discard any commits you make in this\n"
	"state without impacting any branches by switching back to a branch.\n"
	"\n"
	"If you want to create a new branch to retain commits you create, you may\n"
	"do so (now or later) by using -c with the switch command. Example:\n"
	"\n"
	"  git switch -c <new-branch-name>\n"
	"\n"
	"Or undo this operation with:\n"
	"\n"
	"  git switch -\n");

	advise_if_enabled(ADVICE_DETACHED_HEAD, fmt, new_name);
}
