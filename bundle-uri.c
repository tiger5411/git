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

int bundle_uri_advertise(struct repository *r)
{
	if (advertise_bundle_uri != -1)
		goto cached;

	git_config(bundle_uri_config, NULL);
	advertise_bundle_uri = !!bundle_uris.nr;

cached:
	return advertise_bundle_uri;
}

void bundle_uri_value(struct repository *r, struct strbuf *value)
{
	if (!git_env_bool("GIT_TEST_BUNDLE_URI_UNKNOWN_CAPABILITY_VALUE", 0))
		return;
	strbuf_addstr(value, "test-unknown-capability-value");
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

/**
 * General API for {transport,connect}.c etc.
 */
int bundle_uri_parse_line(struct string_list *bundle_uri, const char *line)
{
	size_t i;
	struct string_list columns = STRING_LIST_INIT_DUP;
	const char *uri;
	struct string_list *uri_columns = NULL;
	int ret = 0;

	if (!strlen(line))
		return error(_("bundle-uri: got an empty line"));

	/*
	 * Right now we don't understand anything beyond the first SP,
	 * but let's be tolerant and ignore any future unknown
	 * fields. See the "MUST" note about "bundle-feature-key" in
	 * Documentation/technical/protocol-v2.txt
	 */
	if (string_list_split(&columns, line, ' ', -1) < 1)
		return error(_("bundle-uri: line not in SP-delimited format: %s"), line);

	/*
	 * We represent a "<uri>[ <key-values>...]" line with the URI
	 * being the .string in a string list, and the .util being an
	 * optional string list of key (.string) and values
	 * (.util). If the top-level .util is NULL there's no
	 * key-value pairs....
	 */
	uri = columns.items[0].string;
	if (!strlen(uri)) {
		ret = error(_("bundle-uri: got an empty URI component"));
		goto cleanup;
	}

	/*
	 * ... we're going to need that non-NULL .util .
	 */
	if (columns.nr > 1) {
		uri_columns = xcalloc(1, sizeof(struct string_list));
		string_list_init_dup(uri_columns);
	}

	/*
	 * Let's parse the optional "kv" format, even if we don't
	 * understand any of the keys or values yet.
	 */
	for (i = 1; i < columns.nr; i++) {
		struct string_list kv = STRING_LIST_INIT_DUP;
		const char *arg = columns.items[i].string;
		int fields = string_list_split(&kv, arg, '=', 2);
		int err = 0;

		switch (fields) {
		case 0:
			BUG("should have no fields=0");
		case 1:
			if (!strlen(arg)) {
				err = error("bundle-uri: column %lu: got an empty attribute (full line was '%s')",
					    i, line);
				break;
			}
			/*
			 * We could dance around with
			 * string_list_append_nodup() and skip
			 * string_list_clear(&kv, 0) here, but let's
			 * keep it simple.
			 */
			string_list_append(uri_columns, arg);
			break;
		case 2:
		{
			const char *k = kv.items[0].string;
			const char *v = kv.items[1].string;

			string_list_append(uri_columns, k)->util = xstrdup(v);
			break;
		}
		default:
			err = error("bundle-uri: column %lu: '%s' more than one '=' character (full line was '%s')",
				    i, arg, line);
			break;
		}

		string_list_clear(&kv, 0);
		if (err) {
			ret = err;
			break;
		}
	}


	/*
	 * Per the spec we'll only consider bundle-uri lines OK if
	 * there were no parsing problems, even if the problems were
	 * with attributes whose content we don't understand.
	 */
	if (ret && uri_columns) {
		string_list_clear(uri_columns, 1);
		free(uri_columns);
	} else if (!ret) {
		string_list_append(bundle_uri, uri)->util = uri_columns;
	}

cleanup:
	string_list_clear(&columns, 0);
	return ret;
}

static void bundle_uri_string_list_clear_cb(void *util, const char *string)
{
	struct string_list *fields = util;
	if (!fields)
		return;
	string_list_clear(fields, 1);
	free(fields);
}

void bundle_uri_string_list_clear(struct string_list *bundle_uri)
{
	string_list_clear_func(bundle_uri, bundle_uri_string_list_clear_cb);
}
