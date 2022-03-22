#include "builtin.h"
#include "config.h"
#include "parse-options.h"
#include "utf8.h"

static char const * const usagestr[] = {
	N_("git i18n--helper <command-mode> [<arguments>]"),
	NULL
};

static enum cmdmode {
	I18N_CD_TO_TOPLEVEL = 1,
} cmdmode;

struct cmdmode2msg {
	enum cmdmode mode;
	const char *const msgid;
	const char *arg1;
	const char *arg2;
};

static struct cmdmode2msg cmd2msg[] = {
	{
		I18N_CD_TO_TOPLEVEL,
		N_("Cannot chdir to %s the toplevel of the working tree"),
		"$cdup",
	},
	{ 0 },
};

static void want_argn(const int want, const int got, const char *const msgid,
		      const char * const *ustr, const struct option *options)
{
	if (want == got)
		return;
	usage_msg_optf(_("need %d arguments for '%s' message, got %d"),
		       ustr, options, want, msgid, got);
}

int cmd_i18n__helper(int argc, const char **argv, const char *prefix)
{
	const struct option options[] = {
		OPT_CMDMODE(0, "cd-to-toplevel", &cmdmode,
			 N_("message for git-sh-setup"), I18N_CD_TO_TOPLEVEL),
		OPT_END(),
	};
	struct cmdmode2msg *c2m = cmd2msg;

	argc = parse_options(argc, argv, prefix, options, usagestr,
			     0);
	if (!cmdmode)
		usage_msg_opt(_("need a command-mode argument"),
			      usagestr, options);

	for (c2m = cmd2msg; c2m->mode; c2m++) {
		if (!c2m->mode)
			break;
		if (c2m->mode != cmdmode)
			continue;

		if (!c2m->arg1) {
			puts(_(c2m->msgid));
		} else if (!c2m->arg2) {
			want_argn(1, argc, c2m->msgid, usagestr, options);
			printf(_(c2m->msgid), argv[1]);
			putchar('\n');

void strbuf_utf8_replace(struct strbuf *sb_src, int pos, int width,
			 const char *subst)

		}
		return 0;
	}
	return 0;
}
