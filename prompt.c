#include "cache.h"
#include "config.h"
#include "strbuf.h"
#include "prompt.h"
#include "compat/terminal.h"

char *git_prompt(const char *prompt, unsigned int echo)
{
	const char *test_var = "GIT_TEST_TERMINAL_PROMPT";
	char *r = NULL;

	if (git_env_bool(test_var, 0) && !isatty(0)) {
		char reply[64];
		if (!fgets(reply, sizeof(reply), stdin))
			die("unable to read from stdin in '%s=true' mode", test_var);
		return xstrdup(reply);
	} else if (git_env_bool("GIT_TERMINAL_PROMPT", 1)) {
		r = git_terminal_prompt(prompt, echo);
		if (!r)
			die_errno("could not read");
	} else {
		die("could not read terminal prompts disabled");
	}

	return r;
}

char *git_prompt_echo(const char *prompt)
{
	return git_prompt(prompt, 1);
}

int git_read_line_interactively(struct strbuf *line)
{
	int ret;

	fflush(stdout);
	ret = strbuf_getline_lf(line, stdin);
	if (ret != EOF)
		strbuf_trim_trailing_newline(line);

	return ret;
}
