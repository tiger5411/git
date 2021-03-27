#ifndef OBJECT_FILE_H
#define OBJECT_FILE_H
/**
 * unpack_loose_header() initializes the data stream needed to unpack
 * a loose object header.
 *
 * Returns:
 *
 * - ULHR_OK on success
 * - ULHR_BAD on error
 * - ULHR_TOO_LONG if the header was too long
 *
 * It will only parse up to MAX_HEADER_LEN bytes unless an optional
 * "hdrbuf" argument is non-NULL. This is intended for use with
 * OBJECT_INFO_ALLOW_UNKNOWN_TYPE to extract the bad type for (error)
 * reporting. The full header will be extracted to "hdrbuf" for use
 * with parse_loose_header(), ULHR_TOO_LONG will still be returned
 * from this function to indicate that the header was too long.
 */
enum unpack_loose_header_result {
	ULHR_OK,
	ULHR_BAD,
	ULHR_TOO_LONG,
};
enum unpack_loose_header_result unpack_loose_header(git_zstream *stream,
						    unsigned char *map,
						    unsigned long mapsize,
						    void *buffer,
						    unsigned long bufsiz,
						    struct strbuf *hdrbuf);

struct object_info;
int parse_loose_header(const char *hdr, struct object_info *oi);

/**
 * format_loose_header() is a thin wrapper around s xsnprintf() that
 * writes the initial "<type> <obj-len>" part of the loose object
 * header. It returns the size that snprintf() returns + 1.
 *
 * The format_loose_header_extended() function allows for writing a
 * type_name that's not one of the "enum object_type" types. This is
 * used for "git hash-object --literally". Pass in a OBJ_NONE as the
 * type, and a non-NULL "type_str" to do that.
 *
 * format_loose_header() is a convenience wrapper for
 * format_loose_header_extended().
 */
int format_loose_header_extended(char *str, size_t size, enum object_type type,
				 const char *type_str, size_t objsize);
static inline int format_loose_header(char *str, size_t size,
				      enum object_type type, size_t objsize)
{
	return format_loose_header_extended(str, size, type, NULL, objsize);
}

int check_object_signature(struct repository *r, const struct object_id *oid,
			   void *buf, unsigned long size, const char *type,
			   struct object_id *real_oidp);

int finalize_object_file(const char *tmpfile, const char *filename);

/* Helper to check and "touch" a file */
int check_and_freshen_file(const char *fn, int freshen);

#endif
