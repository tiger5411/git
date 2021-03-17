#include "test-tool.h"
#include "cache.h"

int cmd__read_cache_perf(int argc, const char **argv)
{
	struct repository *r = the_repository;
	int cnt = 1000;

	if (argc == 1)
		cnt = strtol(argv[0], NULL, 0);
	else if (argc)
		die("usage: test-tool read-cache-perf [<count>]");

	setup_git_directory();
	while (cnt--) {
		repo_read_index(r);
		discard_index(r->index);
	}

	return 0;
}
