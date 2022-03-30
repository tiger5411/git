#include "builtin.h"
#include "cache.h"
#include "config.h"
#include "parse-options.h"

static const char * const builtin_sh_i18n_helper_usage[] = {
	N_("git sh-i18n--helper [<msgid>]"),
	NULL
};

int cmd_sh_i18n__helper(int argc, const char **argv, const char *prefix)
{
	struct option options[] = {
		OPT_END()
	};

	argc = parse_options(argc, argv, NULL, options,
			     builtin_sh_i18n_helper_usage, 0);

	if (argc != 1)
		usage_with_options(builtin_sh_i18n_helper_usage, options);

	printf("%s", _(argv[0]));
	return 0;
}
