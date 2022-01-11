#include "cache.h"
#include "lockfile.h"
#include "bundle.h"
#include "object-store.h"
#include "repository.h"
#include "object.h"
#include "commit.h"
#include "diff.h"
#include "revision.h"
#include "list-objects.h"
#include "run-command.h"
#include "refs.h"
#include "strvec.h"
#include "object-array.h"

static const char v2_bundle_signature[] = "# v2 git bundle\n";
static const char v3_bundle_signature[] = "# v3 git bundle\n";
static struct {
	int version;
	const char *signature;
} bundle_sigs[] = {
	{ 2, v2_bundle_signature },
	{ 3, v3_bundle_signature },
};

void bundle_header_init(struct bundle_header *header)
{
	struct bundle_header blank = BUNDLE_HEADER_INIT;
	memcpy(header, &blank, sizeof(*header));
}

void bundle_header_release(struct bundle_header *header)
{
	string_list_clear(&header->prerequisites, 1);
	string_list_clear(&header->references, 1);
}

static int parse_capability(struct bundle_header *header, const char *capability)
{
	const char *arg;
	if (skip_prefix(capability, "object-format=", &arg)) {
		int algo = hash_algo_by_name(arg);
		if (algo == GIT_HASH_UNKNOWN)
			return error(_("unrecognized bundle hash algorithm: %s"), arg);
		header->hash_algo = &hash_algos[algo];
		return 0;
	}
	return error(_("unknown capability '%s'"), capability);
}

static int parse_bundle_signature(struct bundle_header *header, const char *line)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(bundle_sigs); i++) {
		if (!strcmp(line, bundle_sigs[i].signature)) {
			header->version = bundle_sigs[i].version;
			return 0;
		}
	}
	return -1;
}

static int parse_bundle_header(int fd, struct bundle_header *header,
			       const char *report_path)
{
	struct strbuf buf = STRBUF_INIT;
	int status = 0;

	/* The bundle header begins with the signature */
	if (strbuf_getwholeline_fd(&buf, fd, '\n') ||
	    parse_bundle_signature(header, buf.buf)) {
		if (report_path)
			error(_("'%s' does not look like a v2 or v3 bundle file"),
			      report_path);
		status = -1;
		goto abort;
	}

	header->hash_algo = the_hash_algo;

	/* The bundle header ends with an empty line */
	while (!strbuf_getwholeline_fd(&buf, fd, '\n') &&
	       buf.len && buf.buf[0] != '\n') {
		struct object_id oid;
		int is_prereq = 0;
		const char *p;

		strbuf_rtrim(&buf);

		if (header->version == 3 && *buf.buf == '@') {
			if (parse_capability(header, buf.buf + 1)) {
				status = -1;
				break;
			}
			continue;
		}

		if (*buf.buf == '-') {
			is_prereq = 1;
			strbuf_remove(&buf, 0, 1);
		}

		/*
		 * Tip lines have object name, SP, and refname.
		 * Prerequisites have object name that is optionally
		 * followed by SP and subject line.
		 */
		if (parse_oid_hex_algop(buf.buf, &oid, &p, header->hash_algo) ||
		    (*p && !isspace(*p)) ||
		    (!is_prereq && !*p)) {
			if (report_path)
				error(_("unrecognized header: %s%s (%d)"),
				      (is_prereq ? "-" : ""), buf.buf, (int)buf.len);
			status = -1;
			break;
		} else {
			struct object_id *dup = oiddup(&oid);
			if (is_prereq)
				string_list_append(&header->prerequisites, "")->util = dup;
			else
				string_list_append(&header->references, p + 1)->util = dup;
		}
	}

 abort:
	if (status) {
		close(fd);
		fd = -1;
	}
	strbuf_release(&buf);
	return fd;
}

int read_bundle_header(const char *path, struct bundle_header *header)
{
	int fd = open(path, O_RDONLY);

	if (fd < 0)
		return error(_("could not open '%s'"), path);
	return parse_bundle_header(fd, header, path);
}

int is_bundle(const char *path, int quiet)
{
	struct bundle_header header = BUNDLE_HEADER_INIT;
	int fd = open(path, O_RDONLY);

	if (fd < 0)
		return 0;
	fd = parse_bundle_header(fd, &header, quiet ? NULL : path);
	if (fd >= 0)
		close(fd);
	bundle_header_release(&header);
	return (fd >= 0);
}

static int list_refs(struct string_list *r, int argc, const char **argv)
{
	int i;

	for (i = 0; i < r->nr; i++) {
		struct object_id *oid;
		const char *name;

		if (argc > 1) {
			int j;
			for (j = 1; j < argc; j++)
				if (!strcmp(r->items[i].string, argv[j]))
					break;
			if (j == argc)
				continue;
		}

		oid = r->items[i].util;
		name = r->items[i].string;
		printf("%s %s\n", oid_to_hex(oid), name);
	}
	return 0;
}

/* Remember to update object flag allocation in object.h */
#define PREREQ_MARK (1u<<16)

int verify_bundle_extended(struct repository *r, struct bundle_header *header,
			   struct string_list *missing)
{
	/*
	 * Do fast check, then if any prereqs are missing then go line by line
	 * to be verbose about the errors
	 */
	struct string_list *p = &header->prerequisites;
	struct string_list_item *e;
	struct rev_info revs;
	const char *argv[] = {NULL, "--all", NULL};
	struct commit *commit;
	int i, ret = 0, req_nr;

	if (!r || !r->objects || !r->objects->odb)
		return error(_("need a repository to verify a bundle"));

	repo_init_revisions(r, &revs, NULL);
	for_each_string_list_item(e, p) {
		const char *name = e->string;
		struct object_id *oid = e->util;
		struct object *o = parse_object(r, oid);
		if (o) {
			o->flags |= PREREQ_MARK;
			if (strlen(name))
				add_pending_object(&revs, o, name);
			else
				add_pending_object_no_name(&revs, o);
			continue;
		}

		string_list_append(missing, oid_to_hex(oid))->util = xstrdup(name);
	}
	if (revs.pending.nr != p->nr) {
		ret = 1;
		goto cleanup;
	}
	req_nr = revs.pending.nr;
	setup_revisions(2, argv, &revs, NULL);

	if (prepare_revision_walk(&revs))
		die(_("revision walk setup failed"));

	i = req_nr;
	while (i && (commit = get_revision(&revs)))
		if (commit->object.flags & PREREQ_MARK)
			i--;

	for_each_string_list_item(e, p) {
		const char *name = e->string;
		const struct object_id *oid = e->util;
		struct object *o = parse_object(r, oid);
		assert(o); /* otherwise we'd have returned early */
		if (o->flags & SHOWN)
			continue;

		string_list_append(missing, oid_to_hex(oid))->util = xstrdup(name);
		ret = 1;
	}

	/* Clean up objects used, as they will be reused. */
	for_each_string_list_item(e, p) {
		struct object_id *oid = e->util;
		commit = lookup_commit_reference_gently(r, oid, 1);
		if (commit)
			clear_commit_marks(commit, ALL_REV_FLAGS);
	}

cleanup:
	release_revisions(&revs);
	return ret;
}

static int verify_bundle_missing_commits(struct string_list *missing)
{
	struct string_list_item *item;

	error(_("Repository lacks these prerequisite commits:"));
	for_each_string_list_item(item, missing)
		error("%s %s", item->string, (char *)item->util);

	return missing->nr;
}

static void verify_bundle_verbose(struct bundle_header *header)
{
	struct string_list *r;

	r = &header->references;
	printf_ln(Q_("The bundle contains this ref:",
		     "The bundle contains these %d refs:",
		     r->nr),
		  r->nr);
	list_refs(r, 0, NULL);
	r = &header->prerequisites;
	if (!r->nr) {
		printf_ln(_("The bundle records a complete history."));
	} else {
		printf_ln(Q_("The bundle requires this ref:",
			     "The bundle requires these %d refs:",
			     r->nr),
			  r->nr);
		list_refs(r, 0, NULL);
	}
}

int verify_bundle(struct repository *r, struct bundle_header *header,
		  int verbose)
{
	struct string_list missing = STRING_LIST_INIT_DUP;
	int ret;

	if (verify_bundle_extended(r, header, &missing) < 0)
		return -1;
	ret = verify_bundle_missing_commits(&missing);
	if (ret)
		goto cleanup;

	if (verbose)
		verify_bundle_verbose(header);

cleanup:
	string_list_clear(&missing, 1);
	return ret;
}

int list_bundle_refs(struct bundle_header *header, int argc, const char **argv)
{
	return list_refs(&header->references, argc, argv);
}

static int is_tag_in_date_range(struct object *tag, timestamp_t max_age,
				timestamp_t min_age)
{
	unsigned long size;
	enum object_type type;
	char *buf = NULL, *line, *lineend;
	timestamp_t date;
	int result = 1;

	if (max_age == -1 && min_age == -1)
		goto out;

	buf = read_object_file(&tag->oid, &type, &size);
	if (!buf)
		goto out;
	line = memmem(buf, size, "\ntagger ", 8);
	if (!line++)
		goto out;
	lineend = memchr(line, '\n', buf + size - line);
	line = memchr(line, '>', lineend ? lineend - line : buf + size - line);
	if (!line++)
		goto out;
	date = parse_timestamp(line, NULL, 10);
	result = (max_age == -1 || max_age < date) &&
		(min_age == -1 || min_age > date);
out:
	free(buf);
	return result;
}


/* Write the pack data to bundle_fd */
static int write_pack_data(int bundle_fd, struct object_array *pending,
			   struct strvec *pack_options)
{
	struct child_process pack_objects = CHILD_PROCESS_INIT;
	struct object_array_entry *entry;

	strvec_pushl(&pack_objects.args,
		     "pack-objects",
		     "--stdout", "--thin", "--delta-base-offset",
		     NULL);
	strvec_pushv(&pack_objects.args, pack_options->v);
	pack_objects.in = -1;
	pack_objects.out = bundle_fd;
	pack_objects.git_cmd = 1;

	/*
	 * start_command() will close our descriptor if it's >1. Duplicate it
	 * to avoid surprising the caller.
	 */
	if (pack_objects.out > 1) {
		pack_objects.out = dup(pack_objects.out);
		if (pack_objects.out < 0) {
			error_errno(_("unable to dup bundle descriptor"));
			child_process_clear(&pack_objects);
			return -1;
		}
	}

	if (start_command(&pack_objects))
		return error(_("Could not spawn pack-objects"));

	for_each_object_array_entry(entry, pending) {
		struct object *object = entry->item;
		if (object->flags & UNINTERESTING)
			write_or_die(pack_objects.in, "^", 1);
		write_or_die(pack_objects.in, oid_to_hex(&object->oid), the_hash_algo->hexsz);
		write_or_die(pack_objects.in, "\n", 1);
	}
	close(pack_objects.in);
	if (finish_command(&pack_objects))
		return error(_("pack-objects died"));
	return 0;
}

struct stdin_line_cb {
	struct strbuf *seen_refname;
	/* TODO: Can't be embedded, gets zero'd out in revision.c somewhere */
	struct string_list *refname_to_pending;
	int after_handle_revision_arg;
	unsigned int last_pending_nr;
};

static enum rev_info_stdin_line write_bundle_after_stdin_line_again(struct rev_info *revs,
								    struct stdin_line_cb *line_cb)
{
	struct strbuf *seen_refname = line_cb->seen_refname;
	struct string_list *refname_to_pending = line_cb->refname_to_pending;
	unsigned int last_pending_nr = line_cb->last_pending_nr;
	unsigned int pending_nr = revs->pending.nr;
	unsigned nr;

	/*
	 * We may not have a revision to attribute the manually
	 * specified refname to, but we should have a refname.
	 */
	if (!seen_refname->len)
		BUG("should have a seen refname in 'again' callback!");

	/*
	 * A deleted item won't add to pending_nr. See the
	 * "^topic/deleted" test.
	 */
	if (last_pending_nr == pending_nr)
		goto cleanup;

	/*
	 * With non-tabular input we append an empty line for the
	 * convenience of having a 1=1 mapping between the "refnames"
	 * string-list and "revs->pending" in write_bundle_refs()
	 * below.
	 *
	 * If we've had previous deleted items we'll need to pad out
	 * the list up to -1 of our current item...
	 */
	for (nr = refname_to_pending->nr; nr < pending_nr - 1; nr++)
		string_list_append(refname_to_pending, "");

	/*
	 * ... and with the gaps covered, and cases of e.g. "LHS..RHS"
	 * being advanced to the "RHS" we can push our seen refname to
	 * associated with either a good "REV" the "RHS" part of a
	 * "LHS..RHS" range.
	 */
	string_list_append(refname_to_pending, seen_refname->buf);

cleanup:
	strbuf_reset(seen_refname);
	line_cb->after_handle_revision_arg = 0;
	line_cb->last_pending_nr = pending_nr;

	return REV_INFO_STDIN_LINE_CONTINUE;
}

static enum rev_info_stdin_line write_bundle_handle_stdin_line(
	struct rev_info *revs, struct strbuf *line, void *stdin_line_priv)
{
	struct stdin_line_cb *line_cb = stdin_line_priv;
	struct strbuf *seen_refname = line_cb->seen_refname;
	const char delim = '\t';
	const char *refname;
	const char *revname;
	struct string_list fields = STRING_LIST_INIT_DUP;
	size_t i;
	enum rev_info_stdin_line ret = REV_INFO_STDIN_LINE_PROCESS;

	if (line_cb->after_handle_revision_arg) {
		ret = write_bundle_after_stdin_line_again(revs, line_cb);
		goto cleanup;
	}

	/* Parse "<revision>" or "<revision>\t<refname>" input */
	string_list_split(&fields, line->buf, delim, -1);
	for (i = 0; i < fields.nr; i++) {
		const char *field = fields.items[i].string;

		if (i && !*field)
			die(Q_("trailing tab after column #%lu on --stdin line",
			       "trailing tab after column #%lu on --stdin line",
			       i), i);
		switch (i) {
		case 0:
		{
			char *sp;
			const char *p;
			enum object_type type;

			/*
			 * Have a <revision>, may be followed by a
			 * "\t" if there's another field. The
			 * *_split() trimmed any "\t".
			 */
			revname = field;

			/*
			 * We haven't validated "<revname>" which
			 * could contain arbitrary non-"\t" characters
			 * at this point, e.g. "<oid> commit".
			 *
			 * Here we strip " commit", " tree", " blob"
			 * and " tag" as a special-case for consuming
			 * the default for-each-ref format.
			 */
			sp =  strchr(revname, ' ');
			p = sp;
			if (!(sp && p++ && *p))
				continue;

			/*
			 * We're permissive and don't validate that
			 * the stated <OID>/<type> pair describes an
			 * <OID> of type <type>. It won't matter for
			 * the created bundle.
			 */
			for (type = OBJ_COMMIT; type <= OBJ_TAG; type++) {
				if (!strcmp(type_name(type), p))
					*sp = '\0';
				continue;
			}

			/*
			 * Any other validation of "<revname> " will
			 * be done by revision.c's
			 * handle_revision_arg().
			 */
			break;
		}
		case 1:
			refname = field;
			if (check_refname_format(refname, REFNAME_ALLOW_ONELEVEL))
				die(_("'%s' is not a valid ref name"), refname);
			strbuf_addstr(seen_refname, refname);

			/*
			 * Pretend as if only the <revision> was on this line
			 * in revision.c's read_revisions_from_stdin() by
			 * juggling around the strbuf it'll pass to its
			 * handle_revision_arg().
			 */
			strbuf_reset(line);
			strbuf_addstr(line, revname);
			line_cb->after_handle_revision_arg = 1;
			ret = REV_INFO_STDIN_LINE_AGAIN;
			break;
		case 2:
			/*
			 * We don't need to explicitly validate >2 fields,
			 * since check_refname_format() will refuse a refname
			 * with a trailing tab.
			 *
			 * We could supply a max of "2" to strbuf_split_buf()
			 * above instead of -1; but accepting N fields there
			 * makes for better error messages here, as the
			 * invalid ref will contain the trailing tab.
			 */
			die(_("stopped understanding bundle --stdin line at: '%s'"),
			    field);
		}
	}

cleanup:
	string_list_clear(&fields, 0);

	return ret;
}

/*
 * Write out bundle refs based on the tips already
 * parsed into revs.pending. As a side effect, may
 * manipulate revs.pending to include additional
 * necessary objects (like tags).
 *
 * Returns the number of refs written, or negative
 * on error.
 */
static int write_bundle_refs(int bundle_fd, struct object_array *pending,
			     timestamp_t max_age, timestamp_t min_age,
			     struct stdin_line_cb *line_cb)
{
	unsigned int i;
	int ref_count = 0;
	struct string_list *refname_to_pending = line_cb->refname_to_pending;


	for (i = 0; i < pending->nr; i++) {
		char *refname = refname_to_pending->nr > i ?
			refname_to_pending->items[i].string : "";
		struct object_array_entry *e = pending->objects + i;
		struct object_id oid;
		char *ref;
		const char *display_ref;
		int flag;

		if (*refname) {
			display_ref = refname;
			goto write_it;
		}
		if (e->item->flags & UNINTERESTING)
			continue;
		if (dwim_ref(e->name, strlen(e->name), &oid, &ref, 0) != 1)
			goto skip_write_ref;
		if (read_ref_full(e->name, RESOLVE_REF_READING, &oid, &flag))
			flag = 0;
		display_ref = (flag & REF_ISSYMREF) ? e->name : ref;

		if (e->item->type == OBJ_TAG &&
				!is_tag_in_date_range(e->item, max_age, min_age)) {
			e->item->flags |= UNINTERESTING;
			goto skip_write_ref;
		}

		/*
		 * Make sure the refs we wrote out is correct; --max-count and
		 * other limiting options could have prevented all the tips
		 * from getting output.
		 *
		 * Non commit objects such as tags and blobs do not have
		 * this issue as they are not affected by those extra
		 * constraints.
		 */
		if (!(e->item->flags & SHOWN) && e->item->type == OBJ_COMMIT) {
			warning(_("ref '%s' is excluded by the rev-list options"),
				e->name);
			goto skip_write_ref;
		}
		/*
		 * If you run "git bundle create bndl v1.0..v2.0", the
		 * name of the positive ref is "v2.0" but that is the
		 * commit that is referenced by the tag, and not the tag
		 * itself.
		 */
		if (!oideq(&oid, &e->item->oid)) {
			/*
			 * Is this the positive end of a range expressed
			 * in terms of a tag (e.g. v2.0 from the range
			 * "v1.0..v2.0")?
			 */
			struct commit *one = lookup_commit_reference(the_repository, &oid);
			struct object *obj;

			if (e->item == &(one->object)) {
				/*
				 * Need to include e->name as an
				 * independent ref to the pack-objects
				 * input, so that the tag is included
				 * in the output; otherwise we would
				 * end up triggering "empty bundle"
				 * error.
				 */
				obj = parse_object_or_die(&oid, e->name);
				obj->flags |= SHOWN;
				add_object_array(obj, e->name, pending);
			}
			goto skip_write_ref;
		}

	write_it:
		ref_count++;
		write_or_die(bundle_fd, oid_to_hex(&e->item->oid), the_hash_algo->hexsz);
		write_or_die(bundle_fd, " ", 1);
		write_or_die(bundle_fd, display_ref, strlen(display_ref));
		write_or_die(bundle_fd, "\n", 1);
 skip_write_ref:
		if (!*refname)
			free(ref);
	}

	/* end header */
	write_or_die(bundle_fd, "\n", 1);
	return ref_count;
}

struct bundle_prerequisites_info {
	struct object_array *pending;
	int fd;
	timestamp_t max_age;
	timestamp_t min_age;
};

static void write_bundle_prerequisites(struct commit *commit, void *data)
{
	struct bundle_prerequisites_info *bpi = data;
	struct object *object;
	struct pretty_print_context ctx = { 0 };
	struct strbuf buf = STRBUF_INIT;

	if (!(commit->object.flags & BOUNDARY))
		return;
	strbuf_addf(&buf, "-%s ", oid_to_hex(&commit->object.oid));
	write_or_die(bpi->fd, buf.buf, buf.len);

	ctx.fmt = CMIT_FMT_ONELINE;
	ctx.output_encoding = get_log_output_encoding();
	strbuf_reset(&buf);
	pretty_print_commit(&ctx, commit, &buf);
	strbuf_trim(&buf);

	object = (struct object *)commit;
	object->flags |= UNINTERESTING;
	add_object_array(object, buf.buf, bpi->pending);
	strbuf_addch(&buf, '\n');
	write_or_die(bpi->fd, buf.buf, buf.len);
	strbuf_release(&buf);
}

int create_bundle(struct repository *r, const char *path,
		  int argc, const char **argv, struct strvec *pack_options, int version)
{
	struct lock_file lock = LOCK_INIT;
	int bundle_fd = -1;
	int bundle_to_stdout;
	int ref_count = 0;
	struct object_array pending_copy = OBJECT_ARRAY_INIT;
	struct rev_info revs;
	int min_version = the_hash_algo == &hash_algos[GIT_HASH_SHA1] ? 2 : 3;
	struct bundle_prerequisites_info bpi;
	struct strbuf seen_refname = STRBUF_INIT;
	struct string_list refname_to_pending = STRING_LIST_INIT_DUP;
	struct stdin_line_cb line_cb = {
		.seen_refname = &seen_refname,
		.refname_to_pending = &refname_to_pending,
	};
	int ret = 0;
	struct object_array_entry *e;

	bundle_to_stdout = !strcmp(path, "-");
	if (bundle_to_stdout)
		bundle_fd = 1;
	else
		bundle_fd = hold_lock_file_for_update(&lock, path,
						      LOCK_DIE_ON_ERROR);

	if (version == -1)
		version = min_version;

	if (version < 2 || version > 3) {
		die(_("unsupported bundle version %d"), version);
	} else if (version < min_version) {
		die(_("cannot write bundle version %d with algorithm %s"), version, the_hash_algo->name);
	} else if (version == 2) {
		write_or_die(bundle_fd, v2_bundle_signature, strlen(v2_bundle_signature));
	} else {
		const char *capability = "@object-format=";
		write_or_die(bundle_fd, v3_bundle_signature, strlen(v3_bundle_signature));
		write_or_die(bundle_fd, capability, strlen(capability));
		write_or_die(bundle_fd, the_hash_algo->name, strlen(the_hash_algo->name));
		write_or_die(bundle_fd, "\n", 1);
	}

	/* init revs to list objects for pack-objects later */
	save_commit_buffer = 0;
	repo_init_revisions(r, &revs, NULL);
	revs.stdin_line_priv = &line_cb;
	revs.handle_stdin_line = write_bundle_handle_stdin_line;

	argc = setup_revisions(argc, argv, &revs, NULL);
	revs.stdin_line_priv = NULL;

	if (argc > 1) {
		error(_("unrecognized argument: %s"), argv[1]);
		goto err;
	}

	/* save revs.pending in revs_copy for later use */
	for_each_object_array_entry(e, &revs.pending) {
		if (e)
			add_object_array_with_path(e->item, e->name,
						   &pending_copy,
						   e->mode, e->path);
	}

	/* write prerequisites */
	revs.boundary = 1;
	if (prepare_revision_walk(&revs))
		die("revision walk setup failed");
	bpi.fd = bundle_fd;
	bpi.pending = &pending_copy;
	traverse_commit_list(&revs, write_bundle_prerequisites, NULL, &bpi);
	object_array_remove_duplicates(&pending_copy);

	/* write bundle refs */
	ref_count = write_bundle_refs(bundle_fd, &pending_copy,
				      revs.max_age, revs.min_age,
				      &line_cb);
	if (!ref_count)
		die(_("Refusing to create empty bundle."));
	else if (ref_count < 0)
		goto err;

	/* write pack */
	if (write_pack_data(bundle_fd, &pending_copy, pack_options))
		goto err;

	if (!bundle_to_stdout) {
		if (commit_lock_file(&lock))
			die_errno(_("cannot create '%s'"), path);
	}
	goto cleanup;
err:
	rollback_lock_file(&lock);
	ret = -1;
cleanup:
	strbuf_release(&seen_refname);
	string_list_clear(&refname_to_pending, 0);
	release_revisions(&revs);
	object_array_clear(&pending_copy);
	return ret;
}

int unbundle(struct repository *r, struct bundle_header *header,
	     int bundle_fd, struct strvec *extra_index_pack_args)
{
	struct child_process ip = CHILD_PROCESS_INIT;
	strvec_pushl(&ip.args, "index-pack", "--fix-thin", "--stdin", NULL);

	if (extra_index_pack_args) {
		strvec_pushv(&ip.args, extra_index_pack_args->v);
		strvec_clear(extra_index_pack_args);
	}

	if (verify_bundle(r, header, 0))
		return -1;
	ip.in = bundle_fd;
	ip.no_stdout = 1;
	ip.git_cmd = 1;
	if (run_command(&ip))
		return error(_("index-pack died"));
	return 0;
}
