#include "cache.h"
#include "exec-cmd.h"
#include "attr.h"

/*
 * Many parts of Git have subprograms communicate via pipe, expect the
 * upstream of a pipe to die with SIGPIPE when the downstream of a
 * pipe does not need to read all that is written.  Some third-party
 * programs that ignore or block SIGPIPE for their own reason forget
 * to restore SIGPIPE handling to the default before spawning Git and
 * break this carefully orchestrated machinery.
 *
 * Restore the way SIGPIPE is handled to default, which is what we
 * expect.
 */
static void restore_sigpipe_to_default(void)
{
	sigset_t unblock;

	sigemptyset(&unblock);
	sigaddset(&unblock, SIGPIPE);
	sigprocmask(SIG_UNBLOCK, &unblock, NULL);
	signal(SIGPIPE, SIG_DFL);
}

int main(int argc, const char **argv)
{
	int result;

	trace2_initialize_clock();

	/*
	 * Always open file descriptors 0/1/2 to avoid clobbering files
	 * in die().  It also avoids messing up when the pipes are dup'ed
	 * onto stdin/stdout/stderr in the child processes we spawn.
	 */
	sanitize_stdfds();
	restore_sigpipe_to_default();

	git_resolve_executable_dir(argv[0]);

	git_setup_gettext();

	initialize_the_repository();

	attr_start();

	trace2_initialize();
	trace2_cmd_start(argv);
	trace2_collect_process_info(TRACE2_PROCESS_INFO_STARTUP);

	result = cmd_main(argc, argv);

	/*
	 * This is an "exit()" wrapper defined in "git-compat-util.h",
	 * which will do trace2 teardown for us. I.e. we are
	 * guaranteed to correctly log via trace2 even if someone
	 * called exit() before returning from "cmd_main()".
	 */
	exit(result);
}
