#ifndef PROGRESS_H
#define PROGRESS_H
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
	const char *title;
	uint64_t last_value;
	uint64_t total;
	unsigned last_percent;
	unsigned delay;
	struct throughput *throughput;
	uint64_t start_ns;
	struct strbuf counters_sb;
	int title_len;
	int split;
};

#ifdef GIT_TEST_PROGRESS_ONLY

extern int progress_testing;
extern uint64_t progress_test_ns;
void progress_test_force_update(void);

#endif

void display_throughput(struct progress *progress, uint64_t total);
void display_progress(struct progress *progress, uint64_t n);
struct progress *start_progress(const char *title, uint64_t total);
struct progress *start_sparse_progress(const char *title, uint64_t total);
struct progress *start_delayed_progress(const char *title, uint64_t total);
struct progress *start_delayed_sparse_progress(const char *title,
					       uint64_t total);
void stop_progress(struct progress **progress);
void stop_progress_msg(struct progress **progress, const char *msg);

#endif