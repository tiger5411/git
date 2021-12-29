#include "cache.h"
#include "thread-utils.h"
#include "trace2/tr2_tls.h"

/*
 * Initialize size of the thread stack for nested regions.
 * This is used to store nested region start times.  Note that
 * this stack is per-thread and not per-trace-key.
 */
#define TR2_REGION_NESTING_INITIAL_SIZE (100)

static struct tr2tls_thread_ctx *tr2tls_thread_main;
static uint64_t tr2tls_us_start_process;

static pthread_mutex_t tr2tls_mutex;
static pthread_key_t tr2tls_key;

/*
 * This list owns all of the thread-specific CTX data.
 *
 * While a thread is alive it is associated with a CTX (owned by this
 * list) and that CTX is installed in the thread's TLS data area.
 * When a thread exits, it is disassociated from its CTX, but the (now
 * dormant) CTX is held in this list until program exit.
 *
 * Similarly, `tr2tls_thread_main` points to a CTX contained within
 * this list.
 */
static struct tr2tls_thread_ctx *tr2tls_ctx_list; /* modify under lock */
static int tr2_next_thread_id; /* modify under lock */

void tr2tls_start_process_clock(void)
{
	if (tr2tls_us_start_process)
		return;

	/*
	 * Keep the absolute start time of the process (i.e. the main
	 * process) in a fixed variable since other threads need to
	 * access it.  This allows them to do that without a lock on
	 * main thread's array data (because of reallocs).
	 */
	tr2tls_us_start_process = getnanotime() / 1000;
}

struct tr2tls_thread_ctx *tr2tls_create_self(const char *thread_name,
					     uint64_t us_thread_start)
{
	struct tr2tls_thread_ctx *ctx;
	struct strbuf buf_name = STRBUF_INIT;
	int thread_id = tr2tls_locked_increment(&tr2_next_thread_id);

	if (thread_id)
		strbuf_addf(&buf_name, "th%02d:", thread_id);
	strbuf_addstr(&buf_name, thread_name);

	FLEX_ALLOC_MEM(ctx, thread_name, buf_name.buf, buf_name.len);
	strbuf_release(&buf_name);

	ctx->thread_id = thread_id;

	/*
	 * Implicitly "tr2tls_push_self()" to capture the thread's start
	 * time in array_us_start[0].  For the main thread this gives us the
	 * application run time.
	 */
	ctx->alloc = TR2_REGION_NESTING_INITIAL_SIZE;
	ctx->array_us_start = (uint64_t *)xcalloc(ctx->alloc, sizeof(uint64_t));
	ctx->array_us_start[ctx->nr_open_regions++] = us_thread_start;

	/*
	 * Link this CTX into the CTX list and make it the head.
	 */
	pthread_mutex_lock(&tr2tls_mutex);
	ctx->next_ctx = tr2tls_ctx_list;
	tr2tls_ctx_list = ctx;
	pthread_mutex_unlock(&tr2tls_mutex);

	pthread_setspecific(tr2tls_key, ctx);

	return ctx;
}

struct tr2tls_thread_ctx *tr2tls_get_self(void)
{
	struct tr2tls_thread_ctx *ctx;

	if (!HAVE_THREADS)
		return tr2tls_thread_main;

	ctx = pthread_getspecific(tr2tls_key);

	/*
	 * If the thread-proc did not call trace2_thread_start(), we won't
	 * have any TLS data associated with the current thread.  Fix it
	 * here and silently continue.
	 */
	if (!ctx)
		ctx = tr2tls_create_self("unknown", getnanotime() / 1000);

	return ctx;
}

int tr2tls_is_main_thread(void)
{
	if (!HAVE_THREADS)
		return 1;

	return pthread_getspecific(tr2tls_key) == tr2tls_thread_main;
}

void tr2tls_unset_self(void)
{
	pthread_setspecific(tr2tls_key, NULL);
}

void tr2tls_push_self(uint64_t us_now)
{
	struct tr2tls_thread_ctx *ctx = tr2tls_get_self();

	ALLOC_GROW(ctx->array_us_start, ctx->nr_open_regions + 1, ctx->alloc);
	ctx->array_us_start[ctx->nr_open_regions++] = us_now;
}

void tr2tls_pop_self(void)
{
	struct tr2tls_thread_ctx *ctx = tr2tls_get_self();

	if (!ctx->nr_open_regions)
		BUG("no open regions in thread '%s'", ctx->thread_name);

	ctx->nr_open_regions--;
}

void tr2tls_pop_unwind_self(void)
{
	struct tr2tls_thread_ctx *ctx = tr2tls_get_self();

	while (ctx->nr_open_regions > 1)
		tr2tls_pop_self();
}

uint64_t tr2tls_region_elasped_self(uint64_t us)
{
	struct tr2tls_thread_ctx *ctx;
	uint64_t us_start;

	ctx = tr2tls_get_self();
	if (!ctx->nr_open_regions)
		return 0;

	us_start = ctx->array_us_start[ctx->nr_open_regions - 1];

	return us - us_start;
}

uint64_t tr2tls_absolute_elapsed(uint64_t us)
{
	if (!tr2tls_thread_main)
		return 0;

	return us - tr2tls_us_start_process;
}

void tr2tls_init(void)
{
	tr2tls_start_process_clock();

	pthread_key_create(&tr2tls_key, NULL);
	init_recursive_mutex(&tr2tls_mutex);

	tr2tls_thread_main =
		tr2tls_create_self("main", tr2tls_us_start_process);
}

void tr2tls_release(void)
{
	struct tr2tls_thread_ctx *ctx = tr2tls_ctx_list;

	tr2tls_unset_self();
	tr2tls_thread_main = NULL;

	pthread_mutex_destroy(&tr2tls_mutex);
	pthread_key_delete(tr2tls_key);

	while (ctx) {
		struct tr2tls_thread_ctx *next = ctx->next_ctx;

		free(ctx->array_us_start);
		free(ctx);

		ctx = next;
	}
}

int tr2tls_locked_increment(int *p)
{
	int current_value;

	pthread_mutex_lock(&tr2tls_mutex);
	current_value = *p;
	*p = current_value + 1;
	pthread_mutex_unlock(&tr2tls_mutex);

	return current_value;
}
