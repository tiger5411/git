#ifndef PROBE_INFO_H
#define PROBE_INFO_H

/**
 * `probe_info_fn_t`: A callback interface to get information out of
 * other `probe/` APIs. Intended for key-values where the value is a
 * printf-format. Takes a user-provided util (can be NULL).
 */
typedef void (*probe_info_fn_t)(void *util, const char *key, const char *fmt,
				...);
#endif
