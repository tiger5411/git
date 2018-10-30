#include "test-tool.h"
#include "cache.h"
#include "config.h"

int cmd__env_bool(int argc, const char **argv)
{
	return !git_env_bool(argv[1], 0);
}
