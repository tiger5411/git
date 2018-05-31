#ifndef CHECKOUT_H
#define CHECKOUT_H

#include "cache.h"

struct tracking_name_data {
	/* const */ char *src_ref;
	char *dst_ref;
	struct object_id *dst_oid;
	int unique;
};

#define TRACKING_NAME_DATA_INIT { NULL, NULL, NULL, 1 }

/*
 * Check if the branch name uniquely matches a branch name on a remote
 * tracking branch.  Return the name of the remote if such a branch
 * exists, NULL otherwise.
 */
extern const char *unique_tracking_name(const char *name,
					struct object_id *oid);

#endif /* CHECKOUT_H */
