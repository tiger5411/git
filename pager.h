#ifndef PAGER_H
#define PAGER_H
void setup_pager(void);
int pager_in_use(void);
extern int pager_use_color;
int term_columns(void);
void term_clear_line(void);
int decimal_width(uintmax_t);
int check_pager_config(const char *cmd);
void prepare_pager_args(struct child_process *, const char *pager);
#endif
