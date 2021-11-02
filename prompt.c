#include "cache.h"
#include "config.h"
#include "strbuf.h"
#include "prompt.h"
#include "compat/terminal.h"

char *git_prompt(const char *prompt, unsigned int echo)
{
	char *r = NULL;

	if (git_env_bool("GIT_TERMINAL_PROMPT", 1)) {
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
