/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#include "cache.h"
#include "config.h"
#include "object-store.h"
#include "blob.h"
#include "tree.h"
#include "commit.h"
#include "quote.h"
#include "builtin.h"
#include "parse-options.h"
#include "pathspec.h"

static int line_termination = '\n';
#define LS_RECURSIVE 1
#define LS_TREE_ONLY 2
#define LS_SHOW_TREES 4
#define LS_NAME_ONLY 8
#define LS_SHOW_SIZE 16
#define LS_OBJECT_ONLY 32
static int abbrev;
static int ls_options;
static struct pathspec pathspec;
static int chomp_prefix;
static const char *ls_tree_prefix;

/*
 * The format equivalents that show_tree() is prepared to handle.
 */
static const char *ls_tree_format_d = "%(objectmode) %(objecttype) %(objectname)%x09%(path)";
static const char *ls_tree_format_l = "%(objectmode) %(objecttype) %(objectname) %(objectsize:padded)%x09%(path)";
static const char *ls_tree_format_o = "%(objectname)";
static const char *ls_tree_format_n = "%(path)";

static const  char * const ls_tree_usage[] = {
	N_("git ls-tree [<options>] <tree-ish> [<path>...]"),
	NULL
};

struct read_tree_ls_tree_data {
	const char *format;
	struct strbuf sb_scratch;
	struct strbuf sb_tmp;
};

struct expand_ls_tree_data {
	unsigned mode;
	enum object_type type;
	const struct object_id *oid;
	const char *pathname;
	const char *basebuf;
	struct strbuf *sb_scratch;
	struct strbuf *sb_tmp;
};

static int show_recursive(const char *base, size_t baselen, const char *pathname)
{
	int i;

	if (ls_options & LS_RECURSIVE)
		return 1;

	if (!pathspec.nr)
		return 0;

	for (i = 0; i < pathspec.nr; i++) {
		const char *spec = pathspec.items[i].match;
		size_t len, speclen;

		if (strncmp(base, spec, baselen))
			continue;
		len = strlen(pathname);
		spec += baselen;
		speclen = strlen(spec);
		if (speclen <= len)
			continue;
		if (spec[len] && spec[len] != '/')
			continue;
		if (memcmp(pathname, spec, len))
			continue;
		return 1;
	}
	return 0;
}

static void expand_objectsize(struct strbuf *sb,
			      const struct object_id *oid,
			      const enum object_type type,
			      unsigned int padded)
{
	if (type == OBJ_BLOB) {
		unsigned long size;
		if (oid_object_info(the_repository, oid, &size) < 0)
			die(_("could not get object info about '%s'"), oid_to_hex(oid));
		if (padded)
			strbuf_addf(sb, "%7"PRIuMAX, (uintmax_t)size);
		else
			strbuf_addf(sb, "%"PRIuMAX, (uintmax_t)size);
	} else if (padded) {
		strbuf_addf(sb, "%7s", "-");
	} else {
		strbuf_addstr(sb, "-");
	}
}

static size_t expand_show_tree(struct strbuf *sb,
			       const char *start,
			       void *context)
{
	struct expand_ls_tree_data *data = context;
	const char *end;
	const char *p;
	size_t len;

	len = strbuf_expand_literal_cb(sb, start, NULL);
	if (len)
		return len;

	if (*start != '(')
		die(_("bad format as of '%s'"), start);
	end = strchr(start + 1, ')');
	if (!end)
		die(_("ls-tree format element '%s' does not end in ')'"),
		    start);
	len = end - start + 1;

	if (skip_prefix(start, "(objectmode)", &p)) {
		strbuf_addf(sb, "%06o", data->mode);
	} else if (skip_prefix(start, "(objecttype)", &p)) {
		strbuf_addstr(sb, type_name(data->type));
	} else if (skip_prefix(start, "(objectsize:padded)", &p)) {
		expand_objectsize(sb, data->oid, data->type, 1);
	} else if (skip_prefix(start, "(objectsize)", &p)) {
		expand_objectsize(sb, data->oid, data->type, 0);
	} else if (skip_prefix(start, "(objectname)", &p)) {
		strbuf_addstr(sb, find_unique_abbrev(data->oid, abbrev));
	} else if (skip_prefix(start, "(path)", &p)) {
		const char *name = data->basebuf;
		const char *prefix = chomp_prefix ? ls_tree_prefix : NULL;

		if (prefix)
			name = relative_path(name, prefix, data->sb_scratch);
		quote_c_style(name, data->sb_tmp, NULL, 0);
		strbuf_add(sb, data->sb_tmp->buf, data->sb_tmp->len);

		strbuf_reset(data->sb_tmp);
		/* The relative_path() function resets "scratch" */
	} else {
		unsigned int errlen = (unsigned long)len;
		die(_("bad ls-tree format specifiec %%%.*s"), errlen, start);
	}

	return len;
}

static int show_tree_init(enum object_type *type, struct strbuf *base,
			  const char *pathname, unsigned mode, int *retval)
{
	if (S_ISGITLINK(mode)) {
		*type = OBJ_COMMIT;
	} else if (S_ISDIR(mode)) {
		if (show_recursive(base->buf, base->len, pathname)) {
			*retval = READ_TREE_RECURSIVE;
			if (!(ls_options & LS_SHOW_TREES))
				return 1;
		}
		*type = OBJ_TREE;
	}
	else if (ls_options & LS_TREE_ONLY)
		return 1;
	return 0;
}

static int show_tree_fmt(const struct object_id *oid, struct strbuf *base,
			 const char *pathname, unsigned mode, void *context)
{
	struct read_tree_ls_tree_data *data = context;
	struct expand_ls_tree_data my_data = {
		.mode = mode,
		.type = OBJ_BLOB,
		.oid = oid,
		.pathname = pathname,
		.sb_scratch = &data->sb_scratch,
		.sb_tmp = &data->sb_tmp,
	};
	struct strbuf sb = STRBUF_INIT;
	int retval = 0;
	size_t baselen;

	if (show_tree_init(&my_data.type, base, pathname, mode, &retval))
		return retval;

	baselen = base->len;
	strbuf_addstr(base, pathname);
	strbuf_reset(&sb);
	my_data.basebuf = base->buf;

	strbuf_expand(&sb, data->format, expand_show_tree, &my_data);
	strbuf_addch(&sb, line_termination);
	fwrite(sb.buf, sb.len, 1, stdout);
	strbuf_setlen(base, baselen);

	return retval;
}

static int show_tree(const struct object_id *oid, struct strbuf *base,
		const char *pathname, unsigned mode, void *context)
{
	int retval = 0;
	size_t baselen;
	enum object_type type = OBJ_BLOB;

	if (show_tree_init(&type, base, pathname, mode, &retval))
		return retval;

	if (!(ls_options & LS_NAME_ONLY)) {
		if (ls_options & LS_SHOW_SIZE) {
			char size_text[24];
			if (type == OBJ_BLOB) {
				unsigned long size;
				if (oid_object_info(the_repository, oid, &size) == OBJ_BAD)
					xsnprintf(size_text, sizeof(size_text),
						  "BAD");
				else
					xsnprintf(size_text, sizeof(size_text),
						  "%"PRIuMAX, (uintmax_t)size);
			} else {
				xsnprintf(size_text, sizeof(size_text), "-");
			}
			printf("%06o %s %s %7s\t", mode, type_name(type),
			       find_unique_abbrev(oid, abbrev),
			       size_text);
		} else {
			printf("%06o %s %s\t", mode, type_name(type),
			       find_unique_abbrev(oid, abbrev));
		}
	}
	baselen = base->len;
	strbuf_addstr(base, pathname);
	write_name_quoted_relative(base->buf,
				   chomp_prefix ? ls_tree_prefix : NULL,
				   stdout, line_termination);
	strbuf_setlen(base, baselen);
	return retval;
}

int cmd_ls_tree(int argc, const char **argv, const char *prefix)
{
	struct object_id oid;
	struct tree *tree;
	int i, full_tree = 0;
	const char *implicit_format = NULL;
	const char *format = NULL;
	struct read_tree_ls_tree_data read_tree_cb_data = {
		.sb_scratch = STRBUF_INIT,
		.sb_tmp = STRBUF_INIT,
	};
	const struct option ls_tree_options[] = {
		OPT_BIT('d', NULL, &ls_options, N_("only show trees"),
			LS_TREE_ONLY),
		OPT_BIT('r', NULL, &ls_options, N_("recurse into subtrees"),
			LS_RECURSIVE),
		OPT_BIT('t', NULL, &ls_options, N_("show trees when recursing"),
			LS_SHOW_TREES),
		OPT_SET_INT('z', NULL, &line_termination,
			    N_("terminate entries with NUL byte"), 0),
		OPT_BIT('l', "long", &ls_options, N_("include object size"),
			LS_SHOW_SIZE),
		OPT_BIT(0, "name-only", &ls_options, N_("list only filenames"),
			LS_NAME_ONLY),
		OPT_BIT(0, "name-status", &ls_options, N_("list only filenames"),
			LS_NAME_ONLY),
		OPT_BIT(0, "object-only", &ls_options, N_("list only objects"),
			LS_OBJECT_ONLY),
		OPT_SET_INT(0, "full-name", &chomp_prefix,
			    N_("use full path names"), 0),
		OPT_BOOL(0, "full-tree", &full_tree,
			 N_("list entire tree; not just current directory "
			    "(implies --full-name)")),
		OPT_STRING_F(0 , "format", &format, N_("format"),
			     N_("format to use for the output"), PARSE_OPT_NONEG),
		OPT__ABBREV(&abbrev),
		OPT_END()
	};
	read_tree_fn_t fn = show_tree;

	git_config(git_default_config, NULL);
	ls_tree_prefix = prefix;
	if (prefix && *prefix)
		chomp_prefix = strlen(prefix);

	argc = parse_options(argc, argv, prefix, ls_tree_options,
			     ls_tree_usage, 0);
	if (full_tree) {
		ls_tree_prefix = prefix = NULL;
		chomp_prefix = 0;
	}
	/* -d -r should imply -t, but -d by itself should not have to. */
	if ( (LS_TREE_ONLY|LS_RECURSIVE) ==
	    ((LS_TREE_ONLY|LS_RECURSIVE) & ls_options))
		ls_options |= LS_SHOW_TREES;
	if (ls_options & LS_NAME_ONLY)
		implicit_format = ls_tree_format_n;
	if (ls_options & LS_SHOW_SIZE)
		implicit_format = ls_tree_format_l;
	if (ls_options & LS_OBJECT_ONLY)
		implicit_format = ls_tree_format_o;

	if (format && implicit_format)
		usage_msg_opt(_("providing --format cannot be combined with other format-altering options"),
			      ls_tree_usage, ls_tree_options);
	if (implicit_format)
		format = implicit_format;
	if (!format)
		format = ls_tree_format_d;

	if (argc < 1)
		usage_with_options(ls_tree_usage, ls_tree_options);
	if (get_oid(argv[0], &oid))
		die("Not a valid object name %s", argv[0]);

	/*
	 * show_recursive() rolls its own matching code and is
	 * generally ignorant of 'struct pathspec'. The magic mask
	 * cannot be lifted until it is converted to use
	 * match_pathspec() or tree_entry_interesting()
	 */
	parse_pathspec(&pathspec, PATHSPEC_ALL_MAGIC &
				  ~(PATHSPEC_FROMTOP | PATHSPEC_LITERAL),
		       PATHSPEC_PREFER_CWD,
		       prefix, argv + 1);
	for (i = 0; i < pathspec.nr; i++)
		pathspec.items[i].nowildcard_len = pathspec.items[i].len;
	pathspec.has_wildcard = 0;
	tree = parse_tree_indirect(&oid);
	if (!tree)
		die("not a tree object");

	/*
	 * The generic show_tree_fmt() is slower than show_tree(), so
	 * take the fast path if possible.
	 */
	if (format && (!strcmp(format, ls_tree_format_d) ||
		       !strcmp(format, ls_tree_format_l) ||
		       !strcmp(format, ls_tree_format_n)))
		fn = show_tree;
	else if (format)
		fn = show_tree_fmt;
	/*
	 * Allow forcing the show_tree_fmt(), to test that it can
	 * handle the test suite.
	 */
	if (git_env_bool("GIT_TEST_LS_TREE_FORMAT_BACKEND", 0))
		fn = show_tree_fmt;

	read_tree_cb_data.format = format;
	return !!read_tree(the_repository, tree,
			   &pathspec, fn, &read_tree_cb_data);
}
