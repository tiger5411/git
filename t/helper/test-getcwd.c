#include "test-tool.h"
#include "git-compat-util.h"
#include "parse-options.h"

static const char *getcwd_usage[] = {
	"test-tool getcwd",
	NULL
};

int cmd__getcwd(int argc, const char **argv)
{
	struct option options[] = {
		OPT_END()
	};
	char *cwd;

	argc = parse_options(argc, argv, "test-tools", options, getcwd_usage,
			     PARSE_OPT_ERROR_AT_NON_OPTION);

	cwd = xgetcwd();
	puts(cwd);
	free(cwd);

	return 0;
}
