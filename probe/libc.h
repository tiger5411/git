#ifndef PROBE_LIBC_H
#define PROBE_LIBC_H
#include "probe/info.h"

/**
 * probe/libc: Probe libc type and version
 */
int probe_libc(probe_info_fn_t fn, void *util);
#endif
