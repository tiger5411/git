#ifdef PROBE_STANDALONE
#include <stdlib.h>
#else
#include "git-compat-util.h"
#endif

#include "probe/libc.h"
#ifdef __GLIBC__
#include <gnu/libc-version.h>
#endif

int probe_libc(probe_info_fn_t fn, void *util)
{
#ifdef __GLIBC__
	fn(util, "name", "glibc");
	fn(util, "version", gnu_get_libc_version());
#else
	return -1;
#endif
	return 0;
}

#ifdef PROBE_STANDALONE
#include <stdio.h>
#include "probe/print.h"

int main(void)
{
	struct probe_print_data data = {
		.prefix = "PROBE_LIBC_",
	};

	if (probe_libc(probe_print, &data) < 0)
		fprintf(stderr, "warning: unable to detect libc\n");
	return 0;
}
#endif
