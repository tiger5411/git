#ifndef USAGE_H
#define USAGE_H

/**
 * The usage.h is an API for error reporting in git, errors are
 * reported both to the user, to Trace2 (see "trace2.h"), and possibly
 * to custom callbacks via "report_fn" callbacks.
 *
 * `BUG`, `bug`, `die`, `usage`, `error`, and `warning` report errors of
 * various kinds.
 *
 * - `BUG` is for failed internal assertions that should never happen,
 *   i.e. a bug in git itself.
 *
 * - `die` is for fatal application errors.  It prints a message to
 *   the user and exits with status 128.
 *
 * - `usage` is for errors in command line usage.  After printing its
 *   message, it exits with status 129.  (See also `usage_with_options`
 *   in the link:api-parse-options.html[parse-options API].)
 *
 * - `error` is for non-fatal library errors.  It prints a message
 *   to the user and returns -1 for convenience in signaling the error
 *   to the caller.
 *
 * - `bug` (lower-case, not `BUG`) is supposed to be used like `BUG` but
 *   returns -1 like error. The user should then call `BUG_if_bug()` to die.
 *
 *   This is for the convenience of APIs who'd like to potentially report
 *   more than one bug before calling `BUG_if_bug()`, which will invoke
 *   `BUG()` if there were any preceding calls to `bug()`.
 *
 *   We call `BUG_if_bug()` ourselves in on `exit()` (via a wrapper, not
 *   `atexit()`), which guarantees that we'll catch cases where we forgot
 *   to invoke `BUG_if_bug()` following a call or calls to `bug()`.
 *
 * - `warning` is for reporting situations that probably should not
 *   occur but which the user (and Git) can continue to work around
 *   without running into too many problems.  Like `error`, it
 *   returns -1 after reporting the situation to the caller.
 *
 * These reports will be logged via the trace2 facility. See the "error"
 * event in link:api-trace2.txt[trace2 API].
 *
 * Customizable error handlers
 * ---------------------------
 *
 * The default behavior of `die` and `error` is to write a message to
 * stderr and then exit or return as appropriate.  This behavior can be
 * overridden using `set_die_routine` and `set_error_routine`.  For
 * example, "git daemon" uses set_die_routine to write the reason `die`
 * was called to syslog before exiting.
 *
 * Library errors
 * --------------
 *
 * Functions return a negative integer on error.  Details beyond that
 * vary from function to function:
 *
 * - Some functions return -1 for all errors.  Others return a more
 *   specific value depending on how the caller might want to react
 *   to the error.
 *
 * - Some functions report the error to stderr with `error`,
 *   while others leave that for the caller to do.
 *
 * - errno is not meaningful on return from most functions (except
 *   for thin wrappers for system calls).
 *
 * Check the function's API documentation to be sure.
 *
 * Caller-handled errors
 * ---------------------
 *
 * An increasing number of functions take a parameter 'struct strbuf *err'.
 * On error, such functions append a message about what went wrong to the
 * 'err' strbuf.  The message is meant to be complete enough to be passed
 * to `die` or `error` as-is.  For example:
 *
 * 	if (ref_transaction_commit(transaction, &err))
 * 		die("%s", err.buf);
 *
 * The 'err' parameter will be untouched if no error occurred, so multiple
 * function calls can be chained:
 *
 * 	t = ref_transaction_begin(&err);
 * 	if (!t ||
 * 	    ref_transaction_update(t, "HEAD", ..., &err) ||
 * 	    ret_transaction_commit(t, &err))
 * 		die("%s", err.buf);
 *
 * The 'err' parameter must be a pointer to a valid strbuf.  To silence
 * a message, pass a strbuf that is explicitly ignored:
 *
 * 	if (thing_that_can_fail_in_an_ignorable_way(..., &err))
 * 		// This failure is okay.
 * 		strbuf_reset(&err);
 */

/**
 * External but private variables, don't use these except for
 * implementation details of this API itself.
 */
/* Only to be used for testing BUG() implementation (see test-tool) */
extern int BUG_exit_code;
/* If bug() is called we must have a BUG() invocation afterwards */
extern int bug_called_must_BUG;

/* General helper functions invoked via macro wrappers */
__attribute__((format (printf, 3, 4))) NORETURN
void usage_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4))) NORETURN
void die_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4))) NORETURN
void die_errno_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
int die_message_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
int die_message_errno_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
int error_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
int error_errno_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
void warning_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
void warning_errno_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4))) NORETURN
void BUG_fl(const char *file, int line, const char *fmt, ...);
__attribute__((format (printf, 3, 4)))
int bug_fl(const char *file, int line, const char *fmt, ...);

/* General helper macros */
#define usage(...) usage_fl(__FILE__, __LINE__, "%s", __VA_ARGS__)
#define usagef(...) usage_fl(__FILE__, __LINE__, __VA_ARGS__)
#define die(...) die_fl(__FILE__, __LINE__, __VA_ARGS__)
#define die_errno(...) die_errno_fl(__FILE__, __LINE__, __VA_ARGS__)
#define die_message(...) die_message_fl(__FILE__, __LINE__, __VA_ARGS__)
#define die_message_errno(...) die_message_errno_fl(__FILE__, __LINE__, __VA_ARGS__)
#define error(...) error_fl(__FILE__, __LINE__, __VA_ARGS__)
#define error_errno(...) error_errno_fl(__FILE__, __LINE__, __VA_ARGS__)
#define warning(...) warning_fl(__FILE__, __LINE__, __VA_ARGS__)
#define warning_errno(...) warning_errno_fl(__FILE__, __LINE__, __VA_ARGS__)
#define BUG(...) BUG_fl(__FILE__, __LINE__, __VA_ARGS__)
#define bug(...) bug_fl(__FILE__, __LINE__, __VA_ARGS__)
#define BUG_if_bug() do { \
	if (bug_called_must_BUG) { \
		bug_called_must_BUG = 0; \
		BUG_fl(__FILE__, __LINE__, "see bug() output above"); \
	} \
} while (0)

/* Setting custom handling routines */
typedef void (*report_fn)(const char *file, int line, const char *fmt,
			  va_list params);
void set_die_routine(NORETURN_PTR report_fn routine);
report_fn get_die_message_routine(void);
void set_error_routine(report_fn routine);
report_fn get_error_routine(void);
void set_warning_routine(report_fn routine);
report_fn get_warning_routine(void);
void set_die_is_recursing_routine(int (*routine)(void));

/*
 * Let callers be aware of the constant return value; this can help
 * gcc with -Wuninitialized analysis. We restrict this trick to gcc, though,
 * because other compilers may be confused by this.
 */
#if defined(__GNUC__)
static inline int const_error(void)
{
	return -1;
}
#undef error
#undef error_errno
#define error(...) (error_fl(__FILE__, __LINE__, __VA_ARGS__), const_error())
#define error_errno(...) (error_errno_fl(__FILE__, __LINE__, __VA_ARGS__), const_error())
#endif

#endif
