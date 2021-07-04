#include "cache.h"
#include "bundle-uri.h"
#include "pkt-line.h"
#include "config.h"

static void send_bundle_uris(struct packet_writer *writer,
			     struct string_list *uris)
{
	struct string_list_item *item;

	for_each_string_list_item(item, uris)
		packet_writer_write(writer, "%s", item->string);
}

static int advertise_bundle_uri = -1;
static struct string_list bundle_uris = STRING_LIST_INIT_DUP;
static int bundle_uri_config(const char *var, const char *value, void *data)
{
	if (!strcmp(var, "uploadpack.bundleuri")) {
		advertise_bundle_uri = 1;
		string_list_append(&bundle_uris, value);
	}

	return 0;
}

int bundle_uri_advertise(struct repository *r, struct strbuf *value)
{
	if (advertise_bundle_uri != -1)
		goto cached;

	git_config(bundle_uri_config, NULL);
	advertise_bundle_uri = !!bundle_uris.nr;

cached:
	return advertise_bundle_uri;
}

int bundle_uri_command(struct repository *r,
		       struct packet_reader *request)
{
	struct packet_writer writer;
	packet_writer_init(&writer, 1);

	while (packet_reader_read(request) == PACKET_READ_NORMAL)
		die(_("bundle-uri: unexpected argument: '%s'"), request->line);
	if (request->status != PACKET_READ_FLUSH)
		die(_("bundle-uri: expected flush after arguments"));

	send_bundle_uris(&writer, &bundle_uris);

	packet_writer_flush(&writer);

	return 0;
}
