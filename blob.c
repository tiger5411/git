#include "cache.h"
#include "blob.h"
#include "repository.h"
#include "alloc.h"

const char *blob_type = "blob";

struct blob *create_blob(struct repository *r, const struct object_id *oid)
{
	return create_object(r, oid, alloc_blob_node(r));
}

struct blob *lookup_blob_type(struct repository *r,
			      const struct object_id *oid,
			      enum object_type type)
{
	struct object *obj = lookup_object(r, oid);
	if (!obj)
		return create_blob(r, oid);
	if (type != OBJ_NONE && obj->type != OBJ_NONE) {
		if (oid_is_type_or_error(oid, OBJ_BLOB, obj->type) < 0) {
			obj->type = OBJ_BLOB;
			return NULL;
		}
	}
	return object_as_type(obj, OBJ_BLOB);
}

struct blob *lookup_blob(struct repository *r, const struct object_id *oid)
{
	return lookup_blob_type(r, oid, OBJ_NONE);
}
