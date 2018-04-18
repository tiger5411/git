/*
 * Copyright (c) 2018 Ævar Arnfjörð Bjarmason
 *
 * Resolve the merge by picking the Nth (per -X) parent's tree is our
 * new tree.
 */
#include "git-compat-util.h"
#include "builtin.h"
#include "diff.h"

static const char builtin_merge_theirs_usage[] =
	"git merge-theirs <base>... -- HEAD <remote>...";

int cmd_merge_theirs(int argc, const char **argv, const char *prefix)
{
	const char *mainline_str;
	const int argc_offset = 3;
	char *end;
	int mainline;
	const char *branch;
	struct object_id commit;

	if (argc == 2 && !strcmp(argv[1], "-h"))
		usage(builtin_merge_theirs_usage);
	if (argc < 6)
		usage(builtin_merge_theirs_usage);

	/*
	 * Parse the --N part of `git merge-theirs --N base -- HEAD
	 * other-branch [other-branch-2 ...]`.
	 */
	mainline_str = argv[1];
	if (!mainline_str[2])
		usage(builtin_merge_theirs_usage);
	mainline = strtol(mainline_str + 2, &end, 10);
	if (*end || mainline <= 0)
		die(_("'-s theirs -X N' expects a number greater than zero"));
	if (mainline >= (argc - argc_offset))
		die(_("'-s theirs -X N' must come with a corresponding Nth commit to merge!"));

	/* Have the branch name */
	branch = argv[argc_offset + mainline];
	if (get_oid(branch, &commit))
		die(_("could not resolve ref '%s'"), branch);

	fprintf(stderr, "Converted %s to %d. So we select %s with %d\n", mainline_str, mainline, argv[argc_offset + mainline], argc);

	return 0;
}
