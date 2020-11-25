#include "builtin.h"
#include "tag.h"
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

	if (write_object_file(buf.buf, buf.len, tag_type, &result) < 0)
		die("unable to write annotated tag object");

	strbuf_release(&buf);
	printf("%s\n", oid_to_hex(&result));
	return 0;
}
