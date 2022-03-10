#include "git-compat-util.h"
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
