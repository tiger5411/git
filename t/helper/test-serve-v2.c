#include "test-tool.h"
#include "cache.h"
#include "parse-options.h"
#include "serve.h"

static char const * const serve_usage[] = {
	N_("test-tool serve-v2 [<options>]"),
	NULL
};

enum cmd_mode {
	MODE_UNSPECIFIED,
	MODE_STATELESS,
	MODE_ADVERTISE,
};

int cmd__serve_v2(int argc, const char **argv)
{
	enum cmd_mode mode = MODE_UNSPECIFIED;
	struct option options[] = {
		OPT_CMDMODE(0, "stateless-rpc", &mode,
			 N_("quit after a single request/response exchange"),
			MODE_STATELESS),
		OPT_CMDMODE(0, "advertise-capabilities", &mode,
			 N_("exit immediately after advertising capabilities"),
			    MODE_ADVERTISE),
		OPT_END()
	};
	const char *prefix = setup_git_directory();

	/* ignore all unknown cmdline switches for now */
	argc = parse_options(argc, argv, prefix, options, serve_usage,
			     PARSE_OPT_KEEP_DASHDASH |
			     PARSE_OPT_KEEP_UNKNOWN);

	switch (mode) {
	case MODE_ADVERTISE:
		protocol_v2_advertise_capabilities();
		break;
	case MODE_STATELESS:
		protocol_v2_serve_loop(1);
		break;
	case MODE_UNSPECIFIED:
		usage_msg_opt("one of --stateless-rpc or --advertise-capabilities is required",
			      serve_usage, options);
		return 1;
	}

	return 0;
}
