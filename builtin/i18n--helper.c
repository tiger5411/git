#include "builtin.h"
#include "config.h"
#include "parse-options.h"
#include "utf8.h"

static char const *const usagestr[] = {
	N_("git i18n--helper <command-mode> [<arguments>]"),
	NULL
};

static enum cmdmode {
	I18N_CD_TO_TOPLEVEL = 1,
} cmdmode;

static void emit_msg(const int want, const int argc, const char **argv,
		     const char *const *ustr, const struct option *options,
		     const char *const msgid)
{
	if (want != argc)
		usage_msg_optf(_("need %d arguments for '%s' message, got %d"),
			       ustr, options, want, msgid, argc);
	switch (argc) {
	case 1:
		printf(_(msgid), argv[0]);
		break;
	default:
		BUG("expected %d, not %d arguments for '%s' message", want, argc, msgid);
	}
	putchar('\n');
}

int cmd_i18n__helper(int argc, const char **argv, const char *prefix)
{
	const struct option options[] = {
		OPT_CMDMODE(0, "cd-to-toplevel", &cmdmode,
			 N_("message for git-sh-setup"), I18N_CD_TO_TOPLEVEL),
		OPT_END(),
	};

	argc = parse_options(argc, argv, prefix, options, usagestr,
			     0);
	if (!cmdmode)
		usage_msg_opt(_("need a command-mode argument"),
			      usagestr, options);

	switch (cmdmode) {
	case I18N_CD_TO_TOPLEVEL:
		emit_msg(1, argc, argv, usagestr, options,
			 N_("Cannot chdir to %s the toplevel of the working tree"));
		return 0;
	}
	return 0;
}
