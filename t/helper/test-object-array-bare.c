#include "test-tool.h"
#include "cache.h"
#include "object.h"
#include "object-array-bare.h"

int cmd__object_array_bare(int argc, const char **argv)
{
	struct object_array_bare array = OBJECT_ARRAY_BARE_INIT;
	struct strbuf line = STRBUF_INIT;
	struct repository *r = the_repository;

	setup_git_directory();

	while (strbuf_getline(&line, stdin) != EOF) {
		struct object_id oid;
		struct object *obj;

		if (get_oid(line.buf, &oid))
			die("failed to resolve %s", line.buf);
		obj = parse_object(r, &oid);

		object_array_bare_insert(&array, obj);
	}

	object_array_bare_clear(&array);
	strbuf_release(&line);

	return 0;
}
