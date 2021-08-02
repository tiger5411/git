#include "cache.h"

#include "strbuf.h"
#include "strvec.h"
#include "trace2.h"

static int stat_parent_pid(FILE *fp, char *statcomm, int *statppid)
{
	char statstate;
	int statpid;

	int ret = fscanf(fp, "%d %s %c %d", &statpid, statcomm, &statstate,
			 statppid);
	if (ret != 4)
		return -1;
	return 0;
}

static void push_ancestry_name(struct strvec *names, pid_t pid)
{
	struct strbuf procfs_path = STRBUF_INIT;
	char statcomm[PATH_MAX];
	FILE *fp;
	int ppid;

	/* try to use procfs if it's present. */
	strbuf_addf(&procfs_path, "/proc/%d/stat", pid);
	fp = fopen(procfs_path.buf, "r");
	if (!fp)
		return;

	if (stat_parent_pid(fp, statcomm, &ppid) < 0)
		return;

	/*
	 * The comm field is in parenthesis, use printf + offset as a
	 * poor man's trimming of both ends.
	 */
	strvec_pushf(names, "%.*s", (int)strlen(statcomm) - 2, statcomm + 1);

	/*
	 * Both errors and reaching the end of the process chain are
	 * reported as fields of 0 by proc(5)
	 */
	if (ppid != 0)
		push_ancestry_name(names, ppid);
}

void trace2_collect_process_info(enum trace2_process_info_reason reason)
{
	struct strvec names = STRVEC_INIT;

	if (!trace2_is_enabled())
		return;

	switch (reason) {
	case TRACE2_PROCESS_INFO_EXIT:
		break;
	case TRACE2_PROCESS_INFO_STARTUP:
		push_ancestry_name(&names, getppid());

		if (names.nr)
			trace2_cmd_ancestry(names.v);
		strvec_clear(&names);
		break;
	}

	return;
}
