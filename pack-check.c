#include "cache.h"
#include "repository.h"
#include "pack.h"
#include "pack-revindex.h"
#include "progress.h"
#include "packfile.h"
#include "object-store.h"

struct idx_entry {
	off_t                offset;
	union idx_entry_object {
		const unsigned char *hash;
		struct object_id *oid;
	} oid;
	unsigned int nr;
};

int check_pack_crc(struct packed_git *p, struct pack_window **w_curs,
		   off_t offset, off_t len, unsigned int nr)
{
	const uint32_t *index_crc;
	uint32_t data_crc = crc32(0, NULL, 0);

	do {
		unsigned long avail;
		void *data = use_pack(p, w_curs, offset, &avail);
		if (avail > len)
			avail = len;
		data_crc = crc32(data_crc, data, avail);
		offset += avail;
		len -= avail;
	} while (len);

	index_crc = p->index_data;
	index_crc += 2 + 256 + p->num_objects * (the_hash_algo->rawsz/4) + nr;

	return data_crc != ntohl(*index_crc);
}

int verify_pack_index(struct packed_git *p)
{
	off_t index_size;
	const unsigned char *index_base;
	git_hash_ctx ctx;
	unsigned char hash[GIT_MAX_RAWSZ];
	int err = 0;

	if (open_pack_index(p))
		return error("packfile %s index not opened", p->pack_name);
	index_size = p->index_size;
	index_base = p->index_data;

	/* Verify SHA1 sum of the index file */
	the_hash_algo->init_fn(&ctx);
	the_hash_algo->update_fn(&ctx, index_base, (unsigned int)(index_size - the_hash_algo->rawsz));
	the_hash_algo->final_fn(hash, &ctx);
	if (hashcmp(hash, index_base + index_size - the_hash_algo->rawsz))
		err = error("Packfile index for %s hash mismatch",
			    p->pack_name);
	return err;
}
