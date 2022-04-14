/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#define USE_THE_INDEX_COMPATIBILITY_MACROS
#include "builtin.h"
#include "cache.h"
#include "config.h"
#include "tree.h"
#include "cache-tree.h"
#include "parse-options.h"

static const char * const write_tree_usage[] = {
	N_("git write-tree [--missing-ok] [--prefix=<prefix>/]"),
	NULL
};

int cmd_write_tree(int argc, const char **argv, const char *cmd_prefix)
{
	int flags = 0;
	enum write_index_result ret;
	const char *tree_prefix = NULL;
	struct object_id oid;
	struct option write_tree_options[] = {
		OPT_BIT(0, "missing-ok", &flags, N_("allow missing objects"),
			WRITE_TREE_MISSING_OK),
		OPT_STRING(0, "prefix", &tree_prefix, N_("<prefix>/"),
			   N_("write tree object for a subdirectory <prefix>")),
		{ OPTION_BIT, 0, "ignore-cache-tree", &flags, NULL,
		  NULL,
		  PARSE_OPT_HIDDEN | PARSE_OPT_NOARG, NULL,
		  WRITE_TREE_IGNORE_CACHE_TREE },
		OPT_END()
	};

	git_config(git_default_config, NULL);
	parse_options(argc, argv, cmd_prefix, write_tree_options,
		      write_tree_usage, PARSE_OPT_ERROR_AT_NON_OPTION);

	ret = write_cache_as_tree(&oid, flags, tree_prefix);
	switch (ret) {
	case WRITE_TREE_INDEX_OK:
		printf("%s\n", oid_to_hex(&oid));
		return 0;
	case WRITE_TREE_UNMERGED_INDEX:
		/* error() emitted by write_cache_as_tree() */
		return 128;
	case WRITE_TREE_UNREADABLE_INDEX:
		/*
		 * TODO: I think this only happens if the index file
		 * format is corrupt. We use LOCK_DIE_ON_ERROR so just
		 * getting the lock or renaming the file in-place due
		 * to permissions would fail there. This is if
		 * read_index_from() returns -1.
		 */
		error("failed to read the index");
		return 128;
	case WRITE_TREE_PREFIX_ERROR:
		/* error() emitted in write_index_as_tree_internal()? */
		return 128;

	}
	BUG("unreachable");
}
