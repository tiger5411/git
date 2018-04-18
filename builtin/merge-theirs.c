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
	if (argc == 2 && !strcmp(argv[1], "-h"))
		usage(builtin_merge_theirs_usage);


	fprintf(stderr, "hello there!\n");
	die("oh noes");

}
