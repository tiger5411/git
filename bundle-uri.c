#include "cache.h"
#include "bundle-uri.h"
#include "pkt-line.h"
#include "config.h"

/**
 * serve.[ch] API.
 */

/*
 * "uploadpack.bundleURI" is advertised only if there's URIs to serve
 * up per the config.
 */
static int advertise_bundle_uri = -1;

static void send_bundle_uris(struct packet_writer *writer,
			     struct string_list *uris)
{
	struct string_list_item *item;
	for_each_string_list_item(item, uris) {
		const char *uri = item->string;

		packet_writer_write(writer, "%s", uri);
	}
}

static struct string_list bundle_uris = STRING_LIST_INIT_DUP;

static int bundle_uri_startup_config(const char *var, const char *value,
				     void *data)
{
	if (!strcmp(var, "uploadpack.bundleuri")) {
		advertise_bundle_uri = 1;
		string_list_append(&bundle_uris, value);
	}
	return 0;
}

int bundle_uri_advertise(struct repository *r, struct strbuf *value)
{
	if (advertise_bundle_uri == -1) {
		git_config(bundle_uri_startup_config, NULL);
		if (advertise_bundle_uri == -1)
			advertise_bundle_uri = 0;
	}
	return advertise_bundle_uri;
}

int bundle_uri_command(struct repository *r,
		       struct packet_reader *request)
{
	struct packet_writer writer;
	packet_writer_init(&writer, 1);

	while (packet_reader_read(request) == PACKET_READ_NORMAL)
		die("bundle-uri: unexpected argument: '%s'", request->line);
	if (request->status != PACKET_READ_FLUSH)
		die("bundle-uri: expected flush after arguments");

	send_bundle_uris(&writer, &bundle_uris);

	packet_writer_flush(&writer);

	return 0;
}
