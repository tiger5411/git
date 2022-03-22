#include "builtin.h"
#include "config.h"
#include "parse-options.h"

static char const * const env__helper_usage[] = {
	N_("git i18n--helper <command-mode> [<arguments>]"),
	NULL
};

static enum cmdmode {
	I18N_CD_TO_TOPLEVEL = 1,
} cmdmode;

int cmd_i18n__helper(int argc, const char **argv, const char *prefix)
{
	const struct option options[] = {
		OPT_CMDMODE(0, "cd-to-toplevel", &cmdmode,
			 N_("message for git-sh-setup"), I18N_CD_TO_TOPLEVEL),
		OPT_END(),
	};

	argc = parse_options(argc, argv, prefix, options, env__helper_usage,
			     0);
	if (!cmdmode)
		usage_msg_opt(_("need a command-mode argument"),
			      env__helper_usage, options);

	switch (cmdmode) {
	case I18N_CD_TO_TOPLEVEL:
		printf(_("Cannot chdir to %s, the toplevel of the working tree"), argv[0]);
		break;
	}
	return 0;
}
