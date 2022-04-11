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

static void expand_objectsize(struct strbuf *line, const struct object_id *oid,
			      const enum object_type type, unsigned int padded)
{
	if (type == OBJ_BLOB) {
		unsigned long size;
		if (oid_object_info(the_repository, oid, &size) < 0)
			die(_("could not get object info about '%s'"),
			    oid_to_hex(oid));
		if (padded)
			strbuf_addf(line, "%7"PRIuMAX, (uintmax_t)size);
		else
			strbuf_addf(line, "%"PRIuMAX, (uintmax_t)size);
	} else if (padded) {
		strbuf_addf(line, "%7s", "-");
	} else {
		strbuf_addstr(line, "-");
	}
}

struct ls_tree_options {
	int line_termination;
	int abbrev;
	enum ls_tree_path_options {
		LS_RECURSIVE = 1 << 0,
		LS_TREE_ONLY = 1 << 1,
		LS_SHOW_TREES = 1 << 2,
	} ls_options;
	struct pathspec pathspec;
	int chomp_prefix;
	const char *ls_tree_prefix;
	const char *format;
};

struct show_tree_data {
	unsigned mode;
	enum object_type type;
	const struct object_id *oid;
	const char *pathname;
	struct strbuf *base;
};

struct show_tree_data_cb {
	struct ls_tree_options *options;
	struct show_tree_data *data;
};

static size_t expand_show_tree(struct strbuf *sb, const char *start,
			       void *context)
{
	struct show_tree_data_cb *wrapper = context;
	struct ls_tree_options *options = wrapper->options;
	struct show_tree_data *data = wrapper->data;
	const char *end;
	const char *p;
	unsigned int errlen;
	size_t len = strbuf_expand_literal_cb(sb, start, NULL);

	if (len)
		return len;
	if (*start != '(')
		die(_("bad ls-tree format: element '%s' does not start with '('"), start);

	end = strchr(start + 1, ')');
	if (!end)
		die(_("bad ls-tree format: element '%s' does not end in ')'"), start);

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
		strbuf_add_unique_abbrev(sb, data->oid, options->abbrev);
	} else if (skip_prefix(start, "(path)", &p)) {
		const char *name = data->base->buf;
		const char *prefix = options->chomp_prefix ? options->ls_tree_prefix : NULL;
		struct strbuf quoted = STRBUF_INIT;
		struct strbuf sbuf = STRBUF_INIT;
		strbuf_addstr(data->base, data->pathname);
		name = relative_path(data->base->buf, prefix, &sbuf);
		quote_c_style(name, &quoted, NULL, 0);
		strbuf_addbuf(sb, &quoted);
		strbuf_release(&sbuf);
		strbuf_release(&quoted);
	} else {
		errlen = (unsigned long)len;
		die(_("bad ls-tree format: %%%.*s"), errlen, start);
	}
	return len;
}

static int show_recursive(struct ls_tree_options *options, const char *base,
			  size_t baselen, const char *pathname)
{
	int i;

	if (options->ls_options & LS_RECURSIVE)
		return 1;

	if (!options->pathspec.nr)
		return 0;

	for (i = 0; i < options->pathspec.nr; i++) {
		const char *spec = options->pathspec.items[i].match;
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

static int show_tree_fmt(const struct object_id *oid, struct strbuf *base,
			 const char *pathname, unsigned mode, void *context)
{
	struct ls_tree_options *options = context;
	size_t baselen;
	int recurse = 0;
	struct strbuf sb = STRBUF_INIT;
	enum object_type type = object_type(mode);
	struct show_tree_data data = {
		.mode = mode,
		.type = type,
		.oid = oid,
		.pathname = pathname,
		.base = base,
	};
	struct show_tree_data_cb cb_data = {
		.data = &data,
		.options = options,
	};

	if (type == OBJ_TREE && show_recursive(options, base->buf, base->len, pathname))
		recurse = READ_TREE_RECURSIVE;
	if (type == OBJ_TREE && recurse && !(options->ls_options & LS_SHOW_TREES))
		return recurse;
	if (type == OBJ_BLOB && (options->ls_options & LS_TREE_ONLY))
		return 0;

	baselen = base->len;
	strbuf_expand(&sb, options->format, expand_show_tree, &cb_data);
	strbuf_addch(&sb, options->line_termination);
	fwrite(sb.buf, sb.len, 1, stdout);
	strbuf_release(&sb);
	strbuf_setlen(base, baselen);
	return recurse;
}

static int show_tree_common(struct ls_tree_options *options, int *recurse,
			    struct strbuf *base, const char *pathname,
			    enum object_type type)
{
	int ret = -1;
	*recurse = 0;

	if (type == OBJ_BLOB) {
		if (options->ls_options & LS_TREE_ONLY)
			ret = 0;
	} else if (type == OBJ_TREE &&
		   show_recursive(options, base->buf, base->len, pathname)) {
		*recurse = READ_TREE_RECURSIVE;
		if (!(options->ls_options & LS_SHOW_TREES))
			ret = *recurse;
	}

	return ret;
}

static void show_tree_common_default_long(struct ls_tree_options *options,
					  struct strbuf *base,
					  const char *pathname,
					  const size_t baselen)
{
	strbuf_addstr(base, pathname);
	write_name_quoted_relative(base->buf,
				   options->chomp_prefix ? options->ls_tree_prefix : NULL, stdout,
				   options->line_termination);
	strbuf_setlen(base, baselen);
}

static int show_tree_default(const struct object_id *oid, struct strbuf *base,
			     const char *pathname, unsigned mode,
			     void *context)
{
	struct ls_tree_options *options = context;
	int early;
	int recurse;
	enum object_type type = object_type(mode);

	early = show_tree_common(options, &recurse, base, pathname, type);
	if (early >= 0)
		return early;

	printf("%06o %s %s\t", mode, type_name(object_type(mode)),
	       find_unique_abbrev(oid, options->abbrev));
	show_tree_common_default_long(options, base, pathname, base->len);
	return recurse;
}

static int show_tree_long(const struct object_id *oid, struct strbuf *base,
			  const char *pathname, unsigned mode, void *context)
{
	struct ls_tree_options *options = context;
	int early;
	int recurse;
	char size_text[24];
	enum object_type type = object_type(mode);

	early = show_tree_common(options, &recurse, base, pathname, type);
	if (early >= 0)
		return early;

	if (type == OBJ_BLOB) {
		unsigned long size;
		if (oid_object_info(the_repository, oid, &size) == OBJ_BAD)
			xsnprintf(size_text, sizeof(size_text), "BAD");
		else
			xsnprintf(size_text, sizeof(size_text),
				  "%" PRIuMAX, (uintmax_t)size);
	} else {
		xsnprintf(size_text, sizeof(size_text), "-");
	}

	printf("%06o %s %s %7s\t", mode, type_name(type),
	       find_unique_abbrev(oid, options->abbrev), size_text);
	show_tree_common_default_long(options, base, pathname, base->len);
	return recurse;
}

static int show_tree_name_only(const struct object_id *oid, struct strbuf *base,
			       const char *pathname, unsigned mode, void *context)
{
	struct ls_tree_options *options = context;
	int early;
	int recurse;
	const size_t baselen = base->len;
	enum object_type type = object_type(mode);

	early = show_tree_common(options, &recurse, base, pathname, type);
	if (early >= 0)
		return early;

	strbuf_addstr(base, pathname);
	write_name_quoted_relative(base->buf,
				   options->chomp_prefix ? options->ls_tree_prefix : NULL,
				   stdout, options->line_termination);
	strbuf_setlen(base, baselen);
	return recurse;
}

static int show_tree_object(const struct object_id *oid, struct strbuf *base,
			    const char *pathname, unsigned mode, void *context)
{
	struct ls_tree_options *options = context;
	int early;
	int recurse;
	enum object_type type = object_type(mode);

	early = show_tree_common(options, &recurse, base, pathname, type);
	if (early >= 0)
		return early;

	printf("%s%c", find_unique_abbrev(oid, options->abbrev), options->line_termination);
	return recurse;
}

enum ls_tree_cmdmode {
	MODE_DEFAULT = 0,
	MODE_LONG,
	MODE_NAME_ONLY,
	MODE_NAME_STATUS,
	MODE_OBJECT_ONLY,
};

struct ls_tree_cmdmode_to_fmt {
	enum ls_tree_cmdmode mode;
	const char *const fmt;
	read_tree_fn_t fn;
};

static struct ls_tree_cmdmode_to_fmt ls_tree_cmdmode_format[] = {
	{
		.mode = MODE_DEFAULT,
		.fmt = "%(objectmode) %(objecttype) %(objectname)%x09%(path)",
		.fn = show_tree_default,
	},
	{
		.mode = MODE_LONG,
		.fmt = "%(objectmode) %(objecttype) %(objectname) %(objectsize:padded)%x09%(path)",
		.fn = show_tree_long,
	},
	{
		.mode = MODE_NAME_ONLY, /* And MODE_NAME_STATUS */
		.fmt = "%(path)",
		.fn = show_tree_name_only,
	},
	{
		.mode = MODE_OBJECT_ONLY,
		.fmt = "%(objectname)",
		.fn = show_tree_object
	},
	{
		/* fallback */
		.fn = show_tree_default,
	},
};

static const  char * const ls_tree_usage[] = {
	N_("git ls-tree [<options>] <tree-ish> [<path>...]"),
	NULL
};

int cmd_ls_tree(int argc, const char **argv, const char *prefix)
{
	struct object_id oid;
	struct tree *tree;
	int i, full_tree = 0;
	read_tree_fn_t fn = NULL;
	enum ls_tree_cmdmode cmdmode = MODE_DEFAULT;
	struct ls_tree_options options = {
		.line_termination = '\n',
	};
	const struct option ls_tree_options[] = {
		OPT_BIT('d', NULL, &options.ls_options, N_("only show trees"),
			LS_TREE_ONLY),
		OPT_BIT('r', NULL, &options.ls_options, N_("recurse into subtrees"),
			LS_RECURSIVE),
		OPT_BIT('t', NULL, &options.ls_options, N_("show trees when recursing"),
			LS_SHOW_TREES),
		OPT_SET_INT('z', NULL, &options.line_termination,
			    N_("terminate entries with NUL byte"), 0),
		OPT_CMDMODE('l', "long", &cmdmode, N_("include object size"),
			    MODE_LONG),
		OPT_CMDMODE(0, "name-only", &cmdmode, N_("list only filenames"),
			    MODE_NAME_ONLY),
		OPT_CMDMODE(0, "name-status", &cmdmode, N_("list only filenames"),
			    MODE_NAME_STATUS),
		OPT_CMDMODE(0, "object-only", &cmdmode, N_("list only objects"),
			    MODE_OBJECT_ONLY),
		OPT_SET_INT(0, "full-name", &options.chomp_prefix,
			    N_("use full path names"), 0),
		OPT_BOOL(0, "full-tree", &full_tree,
			 N_("list entire tree; not just current directory "
			    "(implies --full-name)")),
		OPT_STRING_F(0, "format", &options.format, N_("format"),
					 N_("format to use for the output"),
					 PARSE_OPT_NONEG),
		OPT__ABBREV(&options.abbrev),
		OPT_END()
	};
	struct ls_tree_cmdmode_to_fmt *m2f = ls_tree_cmdmode_format;
	int ret;

	git_config(git_default_config, NULL);
	options.ls_tree_prefix = prefix;
	if (prefix)
		options.chomp_prefix = strlen(prefix);

	argc = parse_options(argc, argv, prefix, ls_tree_options,
			     ls_tree_usage, 0);
	if (full_tree) {
		options.ls_tree_prefix = prefix = NULL;
		options.chomp_prefix = 0;
	}
	/*
	 * We wanted to detect conflicts between --name-only and
	 * --name-status, but once we're done with that subsequent
	 * code should only need to check the primary name.
	 */
	if (cmdmode == MODE_NAME_STATUS)
		cmdmode = MODE_NAME_ONLY;

	/* -d -r should imply -t, but -d by itself should not have to. */
	if ( (LS_TREE_ONLY|LS_RECURSIVE) ==
	    ((LS_TREE_ONLY|LS_RECURSIVE) & options.ls_options))
		options.ls_options |= LS_SHOW_TREES;

	if (options.format && cmdmode)
		usage_msg_opt(
			_("--format can't be combined with other format-altering options"),
			ls_tree_usage, ls_tree_options);
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
	parse_pathspec(&options.pathspec, PATHSPEC_ALL_MAGIC &
		       ~(PATHSPEC_FROMTOP | PATHSPEC_LITERAL),
		       PATHSPEC_PREFER_CWD,
		       prefix, argv + 1);
	for (i = 0; i < options.pathspec.nr; i++)
		options.pathspec.items[i].nowildcard_len = options.pathspec.items[i].len;
	options.pathspec.has_wildcard = 0;
	tree = parse_tree_indirect(&oid);
	if (!tree)
		die("not a tree object");
	/*
	 * The generic show_tree_fmt() is slower than show_tree(), so
	 * take the fast path if possible.
	 */
	while (m2f) {
		if (!m2f->fmt) {
			fn = options.format ? show_tree_fmt : show_tree_default;
		} else if (options.format && !strcmp(options.format, m2f->fmt)) {
			cmdmode = m2f->mode;
			fn = m2f->fn;
		} else if (!options.format && cmdmode == m2f->mode) {
			fn = m2f->fn;
		} else {
			m2f++;
			continue;
		}
		break;
	}

	ret = !!read_tree(the_repository, tree, &options.pathspec, fn, &options);
	clear_pathspec(&options.pathspec);
	return ret;
}
