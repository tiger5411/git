#ifndef PROBE_PRINT_H
#define PROBE_PRINT_H
#ifdef PROBE_STANDALONE
#include <stdarg.h>
#endif

struct probe_print_data
{
	const char *prefix;
};

static inline void probe_print(void *util, const char *const key,
			       const char *fmt,...)
{
	struct probe_print_data *data = util;
	va_list ap;

	printf("%s%s = ", data->prefix ? data->prefix : "", key);
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	putchar('\n');

	return;
}
#endif
