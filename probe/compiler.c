#include "git-compat-util.h"

#include "probe/compiler.h"
#ifdef __GLIBC__
#include <gnu/libc-version.h>
#endif

int probe_compiler(probe_info_fn_t fn, void *util)
{
#ifdef __clang__
	fn(util, "name", "clang");
	fn(util, "version", __clang_version__);
#elif defined(__GNUC__)
	fn(util, "name", "gcc");
	fn(util, "version", "%d.%d", __GNUC__, __GNUC_MINOR__);
#elif defined(_MSC_VER)
	fn(util, "name", "MSVC");
	fn(util, "version", "%02d.%02d.%05d",
	   _MSC_VER / 100, _MSC_VER % 100, _MSC_FULL_VER % 100000);
#else
	return -1;
#endif
	return 0;
}
