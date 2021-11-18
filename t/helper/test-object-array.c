#include "test-tool.h"
#include "cache.h"
#include "object.h"
#include "object-array.h"

int cmd__object_array(int argc, const char **argv)
{
	struct object_array array = OBJECT_ARRAY_INIT;
	struct strbuf line = STRBUF_INIT;
	struct repository *r = the_repository;

	setup_git_directory();

	while (strbuf_getline(&line, stdin) != EOF) {
		struct object_id oid;
		struct object *obj;

		if (get_oid(line.buf, &oid))
			die("failed to resolve %s", line.buf);
		obj = parse_object(r, &oid);

		add_object_array(obj, NULL, &array);
	}

	object_array_clear(&array);
	strbuf_release(&line);

	return 0;
}
