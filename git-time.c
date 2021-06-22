#include <time.h>
#include "git-time.h"
#include "config.h"

/*
 * Like time(2) but you can fake up the value for testing. We don't
 * bother with supporting taking an argument.
 */

time_t git_time_now(void)
{
	static size_t git_time_now = -2;
	if (git_time_now == -2)
		git_time_now = git_env_ulong("GIT_TEST_TIME_NOW", -1);
	if (git_time_now == -1)
		return time(NULL);
	return git_time_now;
}
