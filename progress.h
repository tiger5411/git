#ifndef PROGRESS_H
#define PROGRESS_H
#include "gettext.h"
#include "strbuf.h"

#define TP_IDX_MAX      8
struct throughput {
	off_t curr_total;
	off_t prev_total;
	uint64_t prev_ns;
	unsigned int avg_bytes;
	unsigned int avg_misecs;
	unsigned int last_bytes[TP_IDX_MAX];
	unsigned int last_misecs[TP_IDX_MAX];
	unsigned int idx;
	struct strbuf display;
};

struct progress {
	const char *title;
	unsigned int verbose:1;
	unsigned int delayed:1;

	/* Internal-only fields */
	unsigned int todo_lazy_init:1;
	unsigned int used_lazy_init:1;

	uint64_t increment_progress_n;

	uint64_t last_value;
	uint64_t total;
	unsigned last_percent;

	unsigned delay;
	unsigned sparse;
	struct throughput *throughput;
	uint64_t start_ns;
	struct strbuf counters_sb;
	int title_len;
	int split;
};
#define PROGRESS_INIT(...) { \
	__VA_ARGS__ \
	.todo_lazy_init = 1, \
	.counters_sb = STRBUF_INIT, \
}

void display_progress(struct progress *progress, uint64_t n);
static inline int increment_progress(struct progress *progress)
{
	display_progress(progress, progress->increment_progress_n++);
	return 1;
}
void stop_progress_msg(struct progress **p_progress, const char *msg);
static inline void stop_progress(struct progress **p_progress)
{
	stop_progress_msg(p_progress, _("done"));
}
static inline int stop_progress_msg_1(struct progress **p_progress)
{
	stop_progress(p_progress);
	return 0;
}

#define FOR_PROGRESS(v, start, end) \
	struct progress *_p = &progress; \
	size_t _e = progress.total = (end); \
	for (v = (start); (increment_progress(_p) && v < _e) ? 1 : stop_progress_msg_1(&_p); v++)

#ifdef GIT_TEST_PROGRESS_ONLY

extern int progress_testing;
extern uint64_t progress_test_ns;
void progress_test_force_update(void);

#endif

void display_throughput(struct progress *progress, uint64_t total);
struct progress *start_progress(const char *title, uint64_t total);
struct progress *start_sparse_progress(const char *title, uint64_t total);
struct progress *start_delayed_progress(const char *title, uint64_t total);
struct progress *start_delayed_sparse_progress(const char *title,
					       uint64_t total);

#endif
