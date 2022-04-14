#ifndef PROBE_COMPILER_H
#define PROBE_COMPILER_H
#include "probe/info.h"

/**
 * probe/compiler: Probe the compiler type and version based on
 * various compiler-specific macros.
 */
int probe_compiler(probe_info_fn_t fn, void *util);
#endif
