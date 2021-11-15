/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#include "git-compat-util.h"
#include "cache.h"

enum usage_kind {
	USAGE_USAGE,
	USAGE_DIE,
	USAGE_ERROR,
	USAGE_WARNING,
	USAGE_BUG,
};

static void vreportf(enum usage_kind kind,
		     const char *file, int line,
		     const char *err, va_list params)
{
	const char *prefix_i18n;
	char prefix[256];
	char msg[4096];
	char *p, *pend = msg + sizeof(msg);
	size_t len;

	switch (kind) {
	case USAGE_USAGE:
		prefix_i18n = _("usage: ");
		break;
	case USAGE_DIE:
		prefix_i18n = _("fatal: ");
		break;
	case USAGE_ERROR:
		prefix_i18n = _("error: ");
		break;
	case USAGE_WARNING:
		prefix_i18n = _("warning: ");
		break;
	case USAGE_BUG:
		prefix_i18n = _("BUG: ");
		break;
	default: /* See https://gcc.gnu.org/bugzilla/show_bug.cgi?id=105273#c2 */
		BUG("unreachable");
	}

	/* truncation via snprintf is OK here */
	if (kind == USAGE_BUG)
		len = snprintf(prefix, sizeof(prefix), "%s%s:%d: ", prefix_i18n, file, line);
	else
		len = snprintf(prefix, sizeof(prefix), "%s", prefix_i18n);

	memcpy(msg, prefix, len);
	p = msg + len;
	if (vsnprintf(p, pend - p, err, params) < 0)
		*p = '\0'; /* vsnprintf() failed, clip at prefix */

	for (; p != pend - 1 && *p; p++) {
		if (iscntrl(*p) && *p != '\t' && *p != '\n')
			*p = '?';
	}

	*(p++) = '\n'; /* we no longer need a NUL */
	fflush(stderr);
	write_in_full(2, msg, p - msg);
}

static NORETURN void usage_builtin(const char *file, int line, const char *err, va_list params)
{
	vreportf(USAGE_USAGE, file, line, err, params);

	/*
	 * When we detect a usage error *before* the command dispatch in
	 * cmd_main(), we don't know what verb to report.  Force it to this
	 * to facilitate post-processing.
	 */
	trace2_cmd_name("_usage_");

	/*
	 * Currently, the (err, params) are usually just the static usage
	 * string which isn't very useful here.  Usually, the call site
	 * manually calls fprintf(stderr,...) with the actual detailed
	 * syntax error before calling usage().
	 *
	 * TODO It would be nice to update the call sites to pass both
	 * the static usage string and the detailed error message.
	 */

	exit(129);
}

static void die_message_builtin(const char *file, int line, const char *err, va_list params)
{
	trace2_cmd_error_va_fl(file, line, err, params);
	vreportf(USAGE_DIE, file, line, err, params);
}

/*
 * We call trace2_cmd_error_va_fl(file, line, ...) in the below functions first and
 * expect it to va_copy 'params' before using it (because an 'ap' can
 * only be walked once).
 */
static NORETURN void die_builtin(const char *file, int line, const char *err, va_list params)
{
	report_fn die_message_fn = get_die_message_routine();

	die_message_fn(file, line, err, params);
	exit(128);
}

static void error_builtin(const char *file, int line, const char *err, va_list params)
{
	trace2_cmd_error_va_fl(file, line, err, params);

	vreportf(USAGE_ERROR, file, line, err, params);
}

static void warning_builtin(const char *file, int line, const char *warn, va_list params)
{
	trace2_cmd_error_va_fl(file, line, warn, params);

	vreportf(USAGE_WARNING, file, line, warn, params);
}

static int die_is_recursing_builtin(void)
{
	static int dying;
	/*
	 * Just an arbitrary number X where "a < x < b" where "a" is
	 * "maximum number of pthreads we'll ever plausibly spawn" and
	 * "b" is "something less than Inf", since the point is to
	 * prevent infinite recursion.
	 */
	static const int recursion_limit = 1024;

	dying++;
	if (dying > recursion_limit) {
		return 1;
	} else if (dying == 2) {
		warning("die() called many times. Recursion error or racy threaded death!");
		return 0;
	} else {
		return 0;
	}
}

/* If we are in a dlopen()ed .so write to a global variable would segfault
 * (ugh), so keep things static. */
static NORETURN_PTR report_fn usage_routine = usage_builtin;
static NORETURN_PTR report_fn die_routine = die_builtin;
static report_fn die_message_routine = die_message_builtin;
static report_fn error_routine = error_builtin;
static report_fn warning_routine = warning_builtin;
static int (*die_is_recursing)(void) = die_is_recursing_builtin;

void set_die_routine(NORETURN_PTR report_fn routine)
{
	die_routine = routine;
}

report_fn get_die_message_routine(void)
{
	return die_message_routine;
}

void set_error_routine(report_fn routine)
{
	error_routine = routine;
}

report_fn get_error_routine(void)
{
	return error_routine;
}

void set_warning_routine(report_fn routine)
{
	warning_routine = routine;
}

report_fn get_warning_routine(void)
{
	return warning_routine;
}

void set_die_is_recursing_routine(int (*routine)(void))
{
	die_is_recursing = routine;
}

static const char *fmt_with_err(char *buf, int n, const char *fmt)
{
	char str_error[256], *err;
	int i, j;

	err = strerror(errno);
	for (i = j = 0; err[i] && j < sizeof(str_error) - 1; ) {
		if ((str_error[j++] = err[i++]) != '%')
			continue;
		if (j < sizeof(str_error) - 1) {
			str_error[j++] = '%';
		} else {
			/* No room to double the '%', so we overwrite it with
			 * '\0' below */
			j--;
			break;
		}
	}
	str_error[j] = 0;
	/* Truncation is acceptable here */
	snprintf(buf, n, "%s: %s", fmt, str_error);
	return buf;
}

NORETURN
void usage_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	usage_routine(file, line, fmt, ap);
	va_end(ap);
}

NORETURN
void die_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	if (die_is_recursing()) {
		fputs("fatal: recursion detected in die handler\n", stderr);
		exit(128);
	}

	va_start(ap, fmt);
	die_routine(file, line, fmt, ap);
	va_end(ap);
}

NORETURN
void die_errno_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;
	char buf[1024];

	if (die_is_recursing()) {
		fputs("fatal: recursion detected in die_errno handler\n",
			stderr);
		exit(128);
	}

	va_start(ap, fmt);
	die_routine(file, line, fmt_with_err(buf, sizeof(buf), fmt), ap);
	va_end(ap);
}

int die_message_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	die_message_routine(file, line, fmt, ap);
	va_end(ap);
	return 128;
}

int die_message_errno_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	die_message_routine(file, line, fmt, ap);
	va_end(ap);
	return 128;
}

int error_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	error_routine(file, line, fmt, ap);
	va_end(ap);
	return -1;
}

int error_errno_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;
	char buf[1024];

	va_start(ap, fmt);
	error_routine(file, line, fmt_with_err(buf, sizeof(buf), fmt), ap);
	va_end(ap);
	return -1;
}

void warning_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	warning_routine(file, line, fmt, ap);
	va_end(ap);
}

void warning_errno_fl(const char *file, int line, const char *fmt, ...)
{
	char buf[1024];
	va_list ap;

	va_start(ap, fmt);
	warning_routine(file, line, fmt_with_err(buf, sizeof(buf), fmt), ap);
	va_end(ap);
}

/* Only set this, ever, from t/helper/, when verifying that bugs are caught. */
int BUG_exit_code;

static NORETURN void BUG_vfl(const char *file, int line, const char *fmt, va_list params)
{
	va_list params_copy;
	static int in_bug;

	va_copy(params_copy, params);
	vreportf(USAGE_BUG, file, line, fmt, params);

	if (in_bug)
		abort();
	in_bug = 1;

	trace2_cmd_error_va_fl(file, line, fmt, params_copy);

	if (BUG_exit_code)
		exit(BUG_exit_code);
	abort();
}

NORETURN void BUG_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	BUG_vfl(file, line, fmt, ap);
	va_end(ap);
}

int bug_called_must_BUG;
int bug_fl(const char *file, int line, const char *fmt, ...)
{
	va_list ap, cp;

	bug_called_must_BUG = 1;

	va_copy(cp, ap);
	va_start(ap, fmt);
	vreportf(USAGE_BUG, file, line, fmt, ap);
	va_end(ap);
	trace2_cmd_error_va_fl(file, line, fmt, cp);

	return -1;
}

#ifdef SUPPRESS_ANNOTATED_LEAKS
void unleak_memory(const void *ptr, size_t len)
{
	static struct suppressed_leak_root {
		struct suppressed_leak_root *next;
		char data[FLEX_ARRAY];
	} *suppressed_leaks;
	struct suppressed_leak_root *root;

	FLEX_ALLOC_MEM(root, data, ptr, len);
	root->next = suppressed_leaks;
	suppressed_leaks = root;
}
#endif
