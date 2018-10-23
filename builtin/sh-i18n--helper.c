#include "builtin.h"
#include "cache.h"
#include "config.h"
#include "parse-options.h"

static const char * const builtin_sh_i18n_helper_usage[] = {
	N_("git sh-i18n--helper [<options>]"),
	NULL
};

int cmd_sh_i18n__helper(int argc, const char **argv, const char *prefix)
{
	int poison = -1;
	struct option options[] = {
		OPT_BOOL(0, "git-test-gettext-poison", &poison,
			 N_("is GIT_TEST_GETTEXT_POISON in effect?")),
		OPT_END()
	};

	argc = parse_options(argc, argv, NULL, options,
			     builtin_sh_i18n_helper_usage, PARSE_OPT_KEEP_ARGV0);

	if (poison != -1)
		return !git_env_bool("GIT_TEST_GETTEXT_POISON", 0);

	usage_with_options(builtin_sh_i18n_helper_usage, options);
}
