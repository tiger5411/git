#include "cache.h"
#include "repository.h"
#include "config.h"
#include "pkt-line.h"
#include "version.h"
#include "strvec.h"
#include "ls-refs.h"
#include "protocol-caps.h"
#include "serve.h"
#include "upload-pack.h"

static int advertise_sid = -1;
static int client_hash_algo = GIT_HASH_SHA1;

static void agent_value(struct repository *r, struct strbuf *value)
{
	strbuf_addstr(value, git_user_agent_sanitized());
}

static void object_format_value(struct repository *r, struct strbuf *value)
{
	strbuf_addstr(value, r->hash_algo->name);
}

static void object_format_receive(struct repository *r,
				  const char *algo_name)
{
	if (!algo_name)
		die("object-format capability requires an argument");

	client_hash_algo = hash_algo_by_name(algo_name);
	if (client_hash_algo == GIT_HASH_UNKNOWN)
		die("unknown object format '%s'", algo_name);
}

static int session_id_advertise(struct repository *r)
{
	if (advertise_sid == -1 &&
	    git_config_get_bool("transfer.advertisesid", &advertise_sid))
		advertise_sid = 0;
	if (!advertise_sid)
		return 0;
	return 1;
}

static void session_id_value(struct repository *r,struct strbuf *value)
{
	strbuf_addstr(value, trace2_session_id());
}

static void session_id_receive(struct repository *r,
			       const char *client_sid)
{
	if (!client_sid)
		client_sid = "";
	trace2_data_string("transfer", NULL, "client-sid", client_sid);
}

struct protocol_capability {
	/*
	 * The name of the capability.  The server uses this name when
	 * advertising this capability, and the client uses this name to
	 * specify this capability.
	 *
	 * This is the only mandatory field, e.g. the "server-option"
	 * capability needs no "advertise", "value", "command" etc.
	 */
	const char *name;

	/*
	 * An optional function that'll be queried to check if the
	 * capability should be advertised. If omitted the capability
	 * will be advertised by default.
	 */
	int (*advertise)(struct repository *r);

	/*
	 * An optional value to add to the capability, This callback
	 * receives and optionally appends to an empty 'value'.
	 *
	 * If a value is added to 'value', the server will advertise this
	 * capability as "<name>=<value>" instead of "<name>".
	 */
	void (*value)(struct repository *r, struct strbuf *value);

	/*
	 * An optional function called when a client requests the
	 * capability as a command, if omitted any attempt to do so is
	 * an error.
	 *
	 * Will be provided a struct packet_reader 'request' which it should
	 * use to read the command specific part of the request.  Every command
	 * MUST read until a flush packet is seen before sending a response.
	 */
	int (*command)(struct repository *r, struct packet_reader *request);

	/*
	 * An optional function called when a client requests the
	 * capability as a non-command.
	 *
	 * For a capability of the form "foo=bar", the value string points to
	 * the content after the "=" (i.e., "bar"). For simple capabilities
	 * (just "foo"), it is NULL.
	 */
	void (*receive)(struct repository *r, const char *value);
};

static struct protocol_capability capabilities[] = {
	{
		.name = "agent",
		.value = agent_value,
	},
	{
		.name = "ls-refs",
		.value = ls_refs_value,
		.command = ls_refs,
	},
	{
		.name = "fetch",
		.value = upload_pack_value,
		.command = upload_pack_v2,
	},
	{
		.name = "server-option",
	},
	{
		.name = "object-format",
		.value = object_format_value,
		.receive = object_format_receive,
	},
	{
		.advertise = session_id_advertise,
		.name = "session-id",
		.value = session_id_value,
		.receive = session_id_receive,
	},
	{
		.name = "object-info",
		.command = cap_object_info,
	},
};

static int is_advertised(struct repository *r, const struct protocol_capability *c)
{
	if (!c->advertise)
		return 1;
	return c->advertise(the_repository);
}

void protocol_v2_advertise_capabilities(void)
{
	struct strbuf value = STRBUF_INIT;
	int i;

	/* serve by default supports v2 */
	packet_write_fmt(1, "version 2\n");

	for (i = 0; i < ARRAY_SIZE(capabilities); i++) {
		struct protocol_capability *c = &capabilities[i];

		if (!is_advertised(the_repository, c))
			continue;

		if (c->value)
			c->value(the_repository, &value);

		if (value.len) {
			packet_write_fmt(1, "%s=%s\n", c->name, value.buf);
			strbuf_reset(&value);
		} else {
			packet_write_fmt(1, "%s\n", c->name);
		}
	}

	packet_flush(1);
	strbuf_release(&value);
}

static struct protocol_capability *get_capability(const char *key, const char **value)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(capabilities); i++) {
		struct protocol_capability *c = &capabilities[i];
		const char *out;
		if (!skip_prefix(key, c->name, &out))
			continue;
		if (!*out) {
			*value = NULL;
			return c;
		}
		if (*out++ == '=') {
			*value = out;
			return c;
		}
	}

	return NULL;
}

static struct protocol_capability *parse_v2_line(const char **line, int *as_cmd,
						 int *is_adv, const char **cap_val)
{
	struct protocol_capability *c;

	*as_cmd = !!skip_prefix(*line, "command=", line);
	*is_adv = 0;

	c = get_capability(*line, cap_val);
	if (!c)
		return NULL;
	if (is_advertised(the_repository, c))
		*is_adv = 1;

	return c;
}

enum request_state {
	PROCESS_REQUEST_KEYS,
	PROCESS_REQUEST_DONE,
};

static struct protocol_capability *process_reader_line(const char *line)
{
	struct protocol_capability *c = NULL;
	int as_cmd;
	int is_adv;
	const char *val;

	c = parse_v2_line(&line, &as_cmd, &is_adv, &val);
	if (!c && as_cmd)
		die("invalid command '%s'", line);
	else if (!c || (!as_cmd && c->command) ||
		 (!is_adv && !c->command))
		die("unknown capability '%s'", line);
	else if ((as_cmd && !c->command) || (!is_adv && c->command) ||
		 (as_cmd && val))
		die("invalid command '%s'", line);

	if (c->receive)
		c->receive(the_repository, val);
	else if (as_cmd)
		return c;

	return NULL;
}

static int process_request(void)
{
	enum request_state state = PROCESS_REQUEST_KEYS;
	struct packet_reader reader;
	int seen_capability_or_command = 0;
	struct protocol_capability *command = NULL;

	packet_reader_init(&reader, 0, NULL, 0,
			   PACKET_READ_CHOMP_NEWLINE |
			   PACKET_READ_GENTLE_ON_EOF |
			   PACKET_READ_DIE_ON_ERR_PACKET);

	/*
	 * Check to see if the client closed their end before sending another
	 * request.  If so we can terminate the connection.
	 */
	if (packet_reader_peek(&reader) == PACKET_READ_EOF)
		return 1;
	reader.options &= ~PACKET_READ_GENTLE_ON_EOF;

	while (state != PROCESS_REQUEST_DONE) {
		switch (packet_reader_peek(&reader)) {
		case PACKET_READ_EOF:
			BUG("Should have already died when seeing EOF");
		case PACKET_READ_NORMAL:
		{
			struct protocol_capability *c = NULL;

			if ((c = process_reader_line(reader.line)))
				command = c;
			seen_capability_or_command = 1;
			/* Consume the peeked line */
			packet_reader_read(&reader);
			break;
		}
		case PACKET_READ_FLUSH:
			/*
			 * If no command and no keys were given then the client
			 * wanted to terminate the connection.
			 */
			if (!seen_capability_or_command)
				return 1;

			/*
			 * The flush packet isn't consume here like it is in
			 * the other parts of this switch statement.  This is
			 * so that the command can read the flush packet and
			 * see the end of the request in the same way it would
			 * if command specific arguments were provided after a
			 * delim packet.
			 */
			state = PROCESS_REQUEST_DONE;
			break;
		case PACKET_READ_DELIM:
			/* Consume the peeked line */
			packet_reader_read(&reader);

			state = PROCESS_REQUEST_DONE;
			break;
		case PACKET_READ_RESPONSE_END:
			BUG("unexpected response end packet");
		}
	}

	if (!command)
		die("no command requested");

	if (client_hash_algo != hash_algo_by_ptr(the_repository->hash_algo))
		die("mismatched object format: server %s; client %s\n",
		    the_repository->hash_algo->name,
		    hash_algos[client_hash_algo].name);

	command->command(the_repository, &reader);

	return 0;
}

void protocol_v2_serve_loop(int stateless_rpc)
{
	if (!stateless_rpc)
		protocol_v2_advertise_capabilities();

	/*
	 * If stateless-rpc was requested then exit after
	 * a single request/response exchange
	 */
	if (stateless_rpc) {
		process_request();
	} else {
		for (;;)
			if (process_request())
				break;
	}
}
