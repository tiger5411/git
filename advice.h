#ifndef ADVICE_H
#define ADVICE_H

#include "git-compat-util.h"
#include "advice-type.h"

struct string_list;

int git_default_advice_config(const char *var, const char *value);
__attribute__((format (printf, 2, 3)))
void advise(enum advice_type type, const char *advice, ...);

/**
 * Checks if advice type is enabled (can be printed to the user).
 * Should be called before advise().
 */
int advice_enabled(enum advice_type type);

/**
 * Checks the visibility of the advice before printing.
 */
__attribute__((format (printf, 2, 3)))
void advise_if_enabled(enum advice_type type, const char *advice, ...);

int error_resolve_conflict(const char *me);
void NORETURN die_resolve_conflict(const char *me);
void NORETURN die_ff_impossible(void);
void advise_on_updating_sparse_paths(struct string_list *pathspec_list);
void detach_advice(const char *new_name);

#endif /* ADVICE_H */
