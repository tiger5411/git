#include "test-tool.h"
#include "git-compat-util.h"
#include "refs.h"

/*
 * usage:
 * tool-test default-branch-name
 */
int cmd__default_branch_name(int argc, const char **argv)
{
	const char *name = git_default_branch_name();

	puts(name);

	return 0;
}
