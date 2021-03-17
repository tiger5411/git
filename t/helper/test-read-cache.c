#include "test-tool.h"
#include "cache.h"
#include "config.h"

int cmd__read_cache(int argc, const char **argv)
{
	struct repository *r = the_repository;
	int i, cnt = 1;
	const char *name = NULL;

	for (++argv, --argc; *argv && starts_with(*argv, "--"); ++argv, --argc) {
		if (skip_prefix(*argv, "--print-and-refresh=", &name))
			continue;
	}

	if (argc == 1)
		cnt = strtol(argv[0], NULL, 0);
	setup_git_directory();
	git_config(git_default_config, NULL);

	for (i = 0; i < cnt; i++) {
		repo_read_index(r);

		if (name) {
			int pos;

			refresh_index(r->index, REFRESH_QUIET,
				      NULL, NULL, NULL);
			pos = index_name_pos(r->index, name, strlen(name));
			if (pos < 0)
				die("%s not in index", name);
			printf("%s is%s up to date\n", name,
			       ce_uptodate(r->index->cache[pos]) ? "" : " not");
			write_file(name, "%d\n", i);
		}
		discard_index(r->index);
	}
	return 0;
}
