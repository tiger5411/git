#ifdef PROBE_STANDALONE
#include <stdlib.h>
#else
#include "git-compat-util.h"
#endif

#include "probe/compiler.h"
#ifdef __GLIBC__
#include <gnu/libc-version.h>
#endif

int probe_compiler(probe_info_fn_t fn, void *util)
{
#ifdef __clang__
	/* See 'clang -dM -E - </dev/null' for available macros */
	fn(util, "name", "clang");
	fn(util, "version", __clang_version__);
#elif defined(__GNUC__)
	/* See 'gcc -dM -E - </dev/null' for available macros */
	fn(util, "name", "gcc");
	fn(util, "version", "%d.%d", __GNUC__, __GNUC_MINOR__);
#elif defined(_MSC_VER)
	fn(util, "name", "MSVC");
	fn(util, "version", "%02d.%02d.%05d",
	   _MSC_VER / 100, _MSC_VER % 100, _MSC_FULL_VER % 100000);
#elif defined(__IBMC__)
	/* See 'xlc -dM -qshowmacros -E /dev/null' for available macros */
	fn(util, "name", "xlc");
	fn(util, "version", "%s", __xlc__);
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
		.prefix = "PROBE_COMPILER_",
	};

	if (probe_compiler(probe_print, &data) < 0)
		fprintf(stderr, "warning: unable to detect compiler type and version\n");
	return 0;
}
#endif
