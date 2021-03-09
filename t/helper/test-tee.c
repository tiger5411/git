#include "test-tool.h"
#include "parse-options.h"
#include "strbuf.h"

static int line_has_tap(struct strbuf *line)
{
	/*
	 * This is a less permissive version of
	 * https://metacpan.org/release/Test-Harness/source/lib/TAP/Parser/Grammar.pm
	 */
	if (starts_with(line->buf, "ok") ||
	    starts_with(line->buf, "not ok") ||
	    starts_with(line->buf, "1..") ||
	    starts_with(line->buf, "Bail out!") ||
	    starts_with(line->buf, "TAP version") ||
	    starts_with(line->buf, "pragma"))
		return 1;
	if (starts_with(line->buf, "#"))
		/*
		 * We're ignoring comments from now, but might treat them
		 * specially in the future for sanctioned messaging from the
		 * test-lib.sh.
		 */
		return 0;
	return  0;
}

int cmd__tee(int argc, const char **argv)
{
	int tap = 0;
	int escape_stdout = 0, escape_file = 0;
	char *prefix = NULL;
	size_t prefix_len = 0;
	const char *tee_usage[] = {
		"test-tool tee [<options>] <FILE>",
		NULL
	};
	struct option options[] = {
		OPT_BOOL(0, "escape-stdout", &escape_stdout,
			 "escape output on stdout"),
		OPT_BOOL(0, "escape-file", &escape_file,
			 "escape output written to file"),
		OPT_BOOL(0, "tap", &tap,
			 "output is TAP"),
		OPT_STRING(0, "prefix", &prefix, "str",
			   "prefix to strip from the output"),
		OPT_END()
	};
	struct strbuf line = STRBUF_INIT;
	FILE *logfp = NULL;

	argc = parse_options(argc, argv, NULL, options,
			     tee_usage, PARSE_OPT_STOP_AT_NON_OPTION);
	if (argc > 1) {
		fprintf(stderr, "got bad option: %s\n", argv[0]);
		usage_with_options(tee_usage, options);
	}
	if (prefix)
		prefix_len = strlen(prefix);

	if (argc)
		logfp = xfopen(argv[0], "w");

	while (strbuf_getline(&line, stdin) != EOF) {
		size_t offs = 0;
		if (prefix && starts_with(line.buf, prefix))
			offs = prefix_len;

		if (!offs && tap && line_has_tap(&line)) {
			if (escape_stdout)
				fprintf(stdout, "\\");
			if (logfp && escape_file)
				fprintf(logfp, "\\");
		}

		fprintf(stdout, "%s\n", line.buf + offs);
		if (logfp)
			fprintf(logfp, "%s\n", line.buf + offs);
	}
	strbuf_release(&line);
	if (logfp)
		fclose(logfp);

	return 0;
}
