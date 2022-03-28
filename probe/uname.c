#ifdef PROBE_STANDALONE
#include <stdlib.h>
#if defined(__MINGW32__)
#error MINGW
#elif defined(_MSC_VER)
#error MSC
#else
#include <sys/utsname.h>
#endif
#else
#include "git-compat-util.h"
#endif

#include "probe/uname.h"

int probe_uname(probe_info_fn_t fn, void *util)
{
	struct utsname buf;

	if (uname(&buf) < 0)
		return -1;

	fn(util, "sysname", buf.sysname);
	fn(util, "release", buf.release);
	fn(util, "version", buf.version);
	fn(util, "machine", buf.machine);
	return 0;
}

#ifdef PROBE_STANDALONE
#include <stdio.h>
#include "probe/print.h"

int main(void)
{
	struct probe_print_data data = {
		.prefix = "PROBE_UNAME_",
	};

	if (probe_uname(probe_print, &data) < 0)
		fprintf(stderr, "warning: unable to detect uname\n");
	return 0;
}
#endif
