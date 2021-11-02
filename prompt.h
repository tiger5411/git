#ifndef PROMPT_H
#define PROMPT_H

char *git_prompt(const char *prompt, unsigned int echo);
char *git_prompt_echo(const char *prompt);
int git_read_line_interactively(struct strbuf *line);

#endif /* PROMPT_H */
