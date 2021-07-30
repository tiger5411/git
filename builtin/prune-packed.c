#include "builtin.h"
#include "parse-options.h"
#include "prune-packed.h"

static const char * const prune_packed_usage[] = {
	"git prune-packed [-n | --dry-run] [-q | --quiet]",
	NULL
};

int cmd_prune_packed(int argc, const char **argv, const char *prefix)
{
	int opts = isatty(2) ? PRUNE_PACKED_VERBOSE : 0;
	const struct option prune_packed_options[] = {
		OPT_BIT('n', "dry-run", &opts, N_("dry run"),
			PRUNE_PACKED_DRY_RUN),
		OPT_NEGBIT('q', "quiet", &opts, N_("be quiet"),
			   PRUNE_PACKED_VERBOSE),
		OPT_END()
	};

	parse_options(argc, argv, prefix, prune_packed_options,
		      prune_packed_usage,
		      PARSE_OPT_ERROR_AT_NON_OPTION);

	prune_packed_objects(opts);
	return 0;
}
