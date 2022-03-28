#ifndef PROBE_UNAME_H
#define PROBE_UNAME_H
#include "probe/info.h"

/**
 * probe/uname: Probe uname(2) info
 */
int probe_uname(probe_info_fn_t fn, void *util);
#endif
