#ifndef PROGRESS_H
#define PROGRESS_H
#include "gettext.h"
#include "strbuf.h"

#define PROGRESS_THROUGHPUT_IDX_MAX      8

struct throughput {
	off_t curr_total;
	off_t prev_total;
	uint64_t prev_ns;
	unsigned int avg_bytes;
	unsigned int avg_misecs;
	unsigned int last_bytes[PROGRESS_THROUGHPUT_IDX_MAX];
	unsigned int last_misecs[PROGRESS_THROUGHPUT_IDX_MAX];
	unsigned int idx;
	struct strbuf display;
};

struct progress {
	struct strbuf title;
	size_t title_len_utf8;

	struct strbuf status;
	size_t status_len_utf8;

	uint64_t last_update;
	uint64_t last_value;
	uint64_t total;
	unsigned last_percent;
	unsigned delay;
	struct throughput *throughput;
	uint64_t start_ns;
	int split;

	/*
	 * The test_* members are are only intended for testing the
	 * progress output, i.e. exclusively for 'test-tool progress'.
	 */
	uint64_t test_getnanotime;
};

/*
 * *_testing() functions are only for use in
 * t/helper/test-progress.c. Do not use them elsewhere!
 */
void test_progress_force_update(void);
struct progress *start_progress_testing(const char *title, uint64_t total);
void test_progress_setnanotime(struct progress *progress, uint64_t time);

void display_throughput(struct progress *progress, uint64_t total);
void display_progress(struct progress *progress, uint64_t n);
void increment_progress(struct progress *progress);
struct progress *start_progress(const char *title, uint64_t total);
struct progress *start_sparse_progress(const char *title, uint64_t total);
struct progress *start_delayed_progress(const char *title, uint64_t total);
struct progress *start_delayed_sparse_progress(const char *title,
					       uint64_t total);
void stop_progress_msg(struct progress **p_progress, const char *msg);
static inline void stop_progress(struct progress **p_progress)
{
	stop_progress_msg(p_progress, _(", done."));
}
void stop_progress_early(struct progress **p_progress);

#define for_progress(exp1,exp2,exp3) \
	for (exp1; increment_progress(progress), exp2; exp3)
#define for_progress_var(progress,exp1,exp2,exp3) \
	for (exp1; increment_progress(progress), exp2; exp3)

#endif
