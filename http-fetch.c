#include "cache.h"
#include "config.h"
#include "exec-cmd.h"
#include "http.h"
#include "strvec.h"
#include "parse-options.h"

static char const * const http_fetch_usage[] = {
	N_("[-v] --packfile=checksum --index-pack-args=<arg>... <url>"),
	N_("[-v] [--recover] [-w ref <commit> | -w ref --stdin] <url>"),
	NULL
};

static void fetch_single_packfile(struct object_id *packfile_hash,
				  const char *url,
				  const char **index_pack_args) {
	struct http_pack_request *preq;
	struct slot_results results;
	int ret;

	http_init(NULL, url, 0);

	preq = new_direct_http_pack_request(packfile_hash->hash, xstrdup(url));
	if (preq == NULL)
		die("couldn't create http pack request");
	preq->slot->results = &results;
	preq->index_pack_args = index_pack_args;
	preq->preserve_index_pack_stdout = 1;

	if (start_active_slot(preq->slot)) {
		run_active_slot(preq->slot);
		if (results.curl_result != CURLE_OK) {
			die("Unable to get pack file %s\n%s", preq->url,
			    curl_errorstr);
		}
	} else {
		die("Unable to start request");
	}

	if ((ret = finish_http_pack_request(preq)))
		die("finish_http_pack_request gave result %d", ret);

	release_http_pack_request(preq);
	http_cleanup();
}

static int fetch_single_bundle(const char *output, const char *url)
{
	struct http_bundle_request *preq;
	struct slot_results results;
	int ret;

	http_init(NULL, url, 0);

	preq = new_direct_http_bundle_request(xstrdup(output), xstrdup(url));
	if (!preq)
		die("couldn't create http bundle request");
	preq->slot->results = &results;

	if (!start_active_slot(preq->slot))
		die("Unable to start request");

	run_active_slot(preq->slot);
	if (results.curl_result != CURLE_OK)
		die("Unable to get bundle file %s\n%s", preq->url,
		    curl_errorstr);

	ret = finish_http_bundle_request(preq);
	if (ret)
		die("finish_http_bundle_request gave result %d", ret);

	release_http_bundle_request(preq);
	http_cleanup();
	return 0;
}

int cmd_main(int argc, const char **argv)
{
	const char *url;
	const char *output = NULL;
	struct object_id packfile_hash = { 0 };
	struct strvec index_pack_args = STRVEC_INIT;
	struct option options[] = {
		OPT_STRING('o', "output", &output, N_("file"),
			   N_("write the downloaded file to <file>")),
		{ OPTION_CALLBACK, 0, "packfile", &packfile_hash,
		  N_("checksum"), N_("the checksum of the packfile"),
		  PARSE_OPT_NONEG, parse_opt_object_id_hex, 0 },
		OPT_STRVEC(0, "index-pack-arg", &index_pack_args, N_("args"),
			   N_("arguments to pass to git-index-pack")),
		OPT_END(),
	};

	setup_git_directory();
	git_config(git_default_config, NULL);

	argc = parse_options(argc, argv, NULL, options, http_fetch_usage, 0);

	if (output) {
		if (argc != 1) {
			error(_("must provide one URL with --output"));
			goto usage;
		}
		url = argv[0];
		return fetch_single_bundle(output, url);
	}

	if (is_null_oid(&packfile_hash)) {
		error(_("must supply --packfile, --stdin or <commit>"));
		goto usage;
	}

	if (is_null_oid(&packfile_hash)) {
		error(_("--packfile is required"));
		goto usage;
	}

	if (!index_pack_args.nr) {
		error(_("--packfile requires --index-pack-args"));
		goto usage;
	}
	if (argc != 1) {
		error(_("must provide one URL with --packfile=*"));
		goto usage;
	}

	url = argv[0];
	fetch_single_packfile(&packfile_hash, url, index_pack_args.v);

	return 0;
usage:
	usage_with_options(http_fetch_usage, options);
}
