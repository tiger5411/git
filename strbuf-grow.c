#include "git-compat-util.h"
#include "strbuf.h"

int cmd_main(int argc, const char **argv)
{
	const char *str = "this is a string that we'll repeatedly insert";
	size_t len = strlen(str);

	int i;
	for (i = 0; i < 1000000; i++) {
		struct strbuf buf = STRBUF_INIT;
		int j;
		for (j = 0; j < 500; j++)
			strbuf_add(&buf, str, len);
		strbuf_release(&buf);
	}
	return 0;
}
