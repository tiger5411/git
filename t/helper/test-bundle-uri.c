#include "test-tool.h"
#include "parse-options.h"
#include "bundle-uri.h"
#include "strbuf.h"
#include "string-list.h"

static int cmd__bundle_uri_parse(int argc, const char **argv)
{
	const char *usage[] = {
		"test-tool bundle-uri parse <in",
		NULL
	};
	struct option options[] = {
		OPT_END(),
	};
	struct strbuf sb = STRBUF_INIT;
	struct string_list list = STRING_LIST_INIT_DUP;
	int err = 0;
	struct string_list_item *item;
	size_t line_nr = 0;

	argc = parse_options(argc, argv, NULL, options, usage, 0);
	if (argc)
		goto usage;

	while (strbuf_getline(&sb, stdin) != EOF) {
		line_nr++;
		if (bundle_uri_parse_line(&list, sb.buf) < 0)
			err = error("bad line: '%s'", sb.buf);
	}

	for_each_string_list_item(item, &list) {
		struct string_list_item *kv_item;
		struct string_list *kv = item->util;

		fprintf(stdout, "%s", item->string);
		if (!kv) {
			fprintf(stdout, "\n");
			continue;
		}
		for_each_string_list_item(kv_item, kv) {
			const char *k = kv_item->string;
			const char *v = kv_item->util;

			if (v)
				fprintf(stdout, " [kv: %s => %s]", k, v);
			else
				fprintf(stdout, " [attr: %s]", k);
		}
		fprintf(stdout, "\n");
	}
	strbuf_release(&sb);

	bundle_uri_string_list_clear(&list);

	return err < 0 ? 1 : 0;
usage:
	usage_with_options(usage, options);
}

int cmd__bundle_uri(int argc, const char **argv)
{
	const char *usage[] = {
		"test-tool bundle-uri <subcommand> [<options>]",
		NULL
	};
	struct option options[] = {
		OPT_END(),
	};

	argc = parse_options(argc, argv, NULL, options, usage,
			     PARSE_OPT_STOP_AT_NON_OPTION |
			     PARSE_OPT_KEEP_ARGV0);
	if (argc == 1)
		goto usage;

	if (!strcmp(argv[1], "parse"))
		return cmd__bundle_uri_parse(argc - 1, argv + 1);
	error("there is no test-tool bundle-uri tool '%s'", argv[1]);

usage:
	usage_with_options(usage, options);
}