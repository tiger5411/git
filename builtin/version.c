#include "builtin.h"

int cmd_version(int argc, const char **argv, const char *prefix)
{
	printf("git version %s\n", git_version_string);
	return 0;
}
