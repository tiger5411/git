#include "builtin.h"
#include "tag.h"
#include "replace-object.h"
#include "object-store.h"
#include "fsck.h"

static int mktag_fsck_error_func(struct fsck_options *o,
				 const struct object_id *oid,
				 enum object_type object_type,
				 int msg_type, const char *message)
{
	switch (msg_type) {
	case FSCK_WARN:
	case FSCK_ERROR:
	case FSCK_EXTRA:
		/*
		 * We treat both warnings and errors as errors, things
		 * like missing "tagger" lines are "only" warnings
		 * under fsck, we've always considered them an error.
		 */
		fprintf_ln(stderr, "error: %s", message);
		return 1;
	default:
		BUG("%d (FSCK_IGNORE?) should never trigger this callback",
		    msg_type);
	}
}

static int verify_object_in_tag(const char *stdin)
{
	struct object_id oid;
	char *eol;
	const char *p;
	int expected_type_id;
	const char *expected_type;
	int ret = -1;
	enum object_type type;
	unsigned long size;
	void *buffer;
	const struct object_id *repl;

	if (!skip_prefix(stdin, "object ", &stdin))
		goto bug;
	if (parse_oid_hex(stdin, &oid, &p) || *p != '\n')
		goto bug;
	stdin = p + 1;
	if (!skip_prefix(stdin, "type ", &stdin))
		goto bug;
	eol = strchr(stdin, '\n');
	expected_type_id = type_from_string_gently(stdin, eol - stdin, 1);
	if (expected_type_id < 0)
		goto bug;
	expected_type = type_name(expected_type_id);

	buffer = read_object_file(&oid, &type, &size);
	repl = lookup_replace_object(the_repository, &oid);

	if (buffer) {
		if (type == type_from_string(expected_type)) {
			ret = check_object_signature(the_repository, repl,
						     buffer, size,
						     expected_type);
		}
		free(buffer);
	}
	goto ok;
bug:
	BUG("fsck_object() should have ensured a sane tag format already!");
ok:
	return ret;
}

int cmd_mktag(int argc, const char **argv, const char *prefix)
{
	struct object obj;
	struct strbuf buf = STRBUF_INIT;
	struct object_id result;
	struct fsck_options fsck_options = FSCK_OPTIONS_STRICT;

	if (argc != 1)
		usage("git mktag");

	if (strbuf_read(&buf, 0, 0) < 0)
		die_errno("could not read from stdin");

	/*
	 * Fake up an object for fsck_object()
	 */
	obj.parsed = 1;
	obj.type = OBJ_TAG;

	fsck_options.extra = 1;
	fsck_options.error_func = mktag_fsck_error_func;
	if (fsck_object(&obj, buf.buf, buf.len, &fsck_options))
		die("tag on stdin did not pass our strict fsck check");

	if (verify_object_in_tag(buf.buf))
		die("tag on stdin did not refer to a valid object");

	if (write_object_file(buf.buf, buf.len, tag_type, &result) < 0)
		die("unable to write annotated tag object");

	strbuf_release(&buf);
	printf("%s\n", oid_to_hex(&result));
	return 0;
}
