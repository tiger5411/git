#ifdef PROBE_STANDALONE
#include <stdlib.h>
#else
#include "git-compat-util.h"
#endif

#include "probe/compiler.h"
#ifdef __GLIBC__
#include <gnu/libc-version.h>
#endif

int probe_config_mak_dev(probe_info_fn_t fn, void *util)
{
#ifdef __clang__
#if __clang_major__ >= 7
	fn(util, "NEEDS_std-eq-gnu99", "1");
#endif
#ifndef __has_warning
#error "Clang version too old to support __has_warning!"
#endif
#if __has_warning("-Wtautological-constant-out-of-range-compare")
	fn(util, "HAS_Wtautological-constant-out-of-range-compare", "1");
#endif
#if __has_warning("-Wextra")
	fn(util, "HAS_Wextra", "1");
#endif
#if __has_warning("-Wpedantic")
	fn(util, "HAS_Wpedantic", "1");
#endif /* __clang__ */

#elif defined(__GNUC__)
#if __GNUC__ == 4
	fn(util, "NEEDS_Wno-uninitialized", "1");
#endif
#if __GNUC__ >= 5
	fn(util, "HAS_Wpedantic", "1");
#if __GNUC__ >= 6
	fn(util, "NEEDS_std-eq-gnu99", "1");
	fn(util, "HAS_Wextra", "1");
#if __GNUC__ >= 10
	fn(util, "HAS_Wno-pedantic-ms-format", "1");
#endif /* >= 10 */
#endif /* >= 6 */
#endif /* >= 5 */

#elif defined(__IBMC__)

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

	if (probe_config_mak_dev(probe_print, &data) < 0)
		fprintf(stderr, "warning: unable to detect compiler type and version\n");
	return 0;
}
#endif
