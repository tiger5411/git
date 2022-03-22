#include "builtin.h"
#include "config.h"
#include "parse-options.h"

static char const * const env__helper_usage[] = {
	N_("git i18n--helper <message-id> [<arguments>]"),
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
	return 0;
}
