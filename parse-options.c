#include "git-compat-util.h"
#include "parse-options.h"
#include "cache.h"
#include "config.h"
#include "commit.h"
#include "color.h"
#include "utf8.h"

enum opt_parsed {
	OPT_LONG  = 0,
	OPT_SHORT = 1<<0,
	OPT_UNSET = 1<<1,
};

static int optbug(const struct option *opt, const char *reason)
{
	if (opt->long_name) {
		if (opt->short_name)
			return error("BUG: switch '%c' (--%s) %s",
				     opt->short_name, opt->long_name, reason);
		return error("BUG: option '%s' %s", opt->long_name, reason);
	} else if (opt->type == OPTION_GROUP) {
		return error("BUG: option group has bad help '%s': %s", opt->help,
			     reason);
	}
	return error("BUG: switch '%c' %s", opt->short_name, reason);
}

static const char *optname(const struct option *opt, enum opt_parsed flags)
{
	static struct strbuf sb = STRBUF_INIT;

	strbuf_reset(&sb);
	if (flags & OPT_SHORT)
		strbuf_addf(&sb, "switch `%c'", opt->short_name);
	else if (flags & OPT_UNSET)
		strbuf_addf(&sb, "option `no-%s'", opt->long_name);
	else if (flags == OPT_LONG)
		strbuf_addf(&sb, "option `%s'", opt->long_name);
	else
		BUG("optname() got unknown flags %d", flags);

	return sb.buf;
}

static enum parse_opt_result get_arg(struct parse_opt_ctx_t *p,
				     const struct option *opt,
				     enum opt_parsed flags, const char **arg)
{
	if (p->opt) {
		*arg = p->opt;
		p->opt = NULL;
	} else if (p->argc == 1 && (opt->flags & PARSE_OPT_LASTARG_DEFAULT)) {
		*arg = (const char *)opt->defval;
	} else if (p->argc > 1) {
		p->argc--;
		*arg = *++p->argv;
	} else
		return error(_("%s requires a value"), optname(opt, flags));
	return 0;
}

static void fix_filename(const char *prefix, const char **file)
{
	if (!file || !*file || !prefix || is_absolute_path(*file)
	    || !strcmp("-", *file))
		return;
	*file = prefix_filename(prefix, *file);
}

static enum parse_opt_result opt_command_mode_error(
	const struct option *opt,
	const struct option *all_opts,
	enum opt_parsed flags)
{
	const struct option *that;
	struct strbuf that_name = STRBUF_INIT;

	/*
	 * Find the other option that was used to set the variable
	 * already, and report that this is not compatible with it.
	 */
	for (that = all_opts; that->type != OPTION_END; that++) {
		if (that == opt ||
		    !(that->flags & PARSE_OPT_CMDMODE) ||
		    that->value != opt->value ||
		    that->defval != *(int *)opt->value)
			continue;

		if (that->long_name)
			strbuf_addf(&that_name, "--%s", that->long_name);
		else
			strbuf_addf(&that_name, "-%c", that->short_name);
		error(_("%s is incompatible with %s"),
		      optname(opt, flags), that_name.buf);
		strbuf_release(&that_name);
		return PARSE_OPT_ERROR;
	}
	return error(_("%s : incompatible with something else"),
		     optname(opt, flags));
}

static enum parse_opt_result get_value(struct parse_opt_ctx_t *p,
				       const struct option *opt,
				       const struct option *all_opts,
				       enum opt_parsed flags)
{
	const char *s, *arg;
	const int unset = flags & OPT_UNSET;
	int err;

	if (unset && p->opt)
		return error(_("%s takes no value"), optname(opt, flags));
	if (unset && (opt->flags & PARSE_OPT_NONEG))
		return error(_("%s isn't available"), optname(opt, flags));
	if (!(flags & OPT_SHORT) && p->opt && (opt->flags & PARSE_OPT_NOARG))
		return error(_("%s takes no value"), optname(opt, flags));

	/*
	 * Giving the same mode option twice, although unnecessary,
	 * is not a grave error, so let it pass.
	 */
	if ((opt->flags & PARSE_OPT_CMDMODE) &&
	    *(int *)opt->value && *(int *)opt->value != opt->defval)
		return opt_command_mode_error(opt, all_opts, flags);

	switch (opt->type) {
	case OPTION_LOWLEVEL_CALLBACK:
		return opt->ll_callback(p, opt, NULL, unset);

	case OPTION_BIT:
		if (unset)
			*(int *)opt->value &= ~opt->defval;
		else
			*(int *)opt->value |= opt->defval;
		return 0;

	case OPTION_NEGBIT:
		if (unset)
			*(int *)opt->value |= opt->defval;
		else
			*(int *)opt->value &= ~opt->defval;
		return 0;

	case OPTION_COUNTUP:
		if (*(int *)opt->value < 0)
			*(int *)opt->value = 0;
		*(int *)opt->value = unset ? 0 : *(int *)opt->value + 1;
		return 0;

	case OPTION_SET_INT:
		*(int *)opt->value = unset ? 0 : opt->defval;
		return 0;

	case OPTION_STRING:
		if (unset)
			*(const char **)opt->value = NULL;
		else if (opt->flags & PARSE_OPT_OPTARG && !p->opt)
			*(const char **)opt->value = (const char *)opt->defval;
		else
			return get_arg(p, opt, flags, (const char **)opt->value);
		return 0;

	case OPTION_FILENAME:
		err = 0;
		if (unset)
			*(const char **)opt->value = NULL;
		else if (opt->flags & PARSE_OPT_OPTARG && !p->opt)
			*(const char **)opt->value = (const char *)opt->defval;
		else
			err = get_arg(p, opt, flags, (const char **)opt->value);

		if (!err)
			fix_filename(p->prefix, (const char **)opt->value);
		return err;

	case OPTION_CALLBACK:
	{
		const char *p_arg = NULL;
		int p_unset;

		if (unset)
			p_unset = 1;
		else if (opt->flags & PARSE_OPT_NOARG)
			p_unset = 0;
		else if (opt->flags & PARSE_OPT_OPTARG && !p->opt)
			p_unset = 0;
		else if (get_arg(p, opt, flags, &arg))
			return -1;
		else {
			p_unset = 0;
			p_arg = arg;
		}
		if (opt->callback)
			return (*opt->callback)(opt, p_arg, p_unset) ? (-1) : 0;
		else
			return (*opt->ll_callback)(p, opt, p_arg, p_unset);
	}
	case OPTION_INTEGER:
		if (unset) {
			*(int *)opt->value = 0;
			return 0;
		}
		if (opt->flags & PARSE_OPT_OPTARG && !p->opt) {
			*(int *)opt->value = opt->defval;
			return 0;
		}
		if (get_arg(p, opt, flags, &arg))
			return -1;
		if (!*arg)
			return error(_("%s expects a numerical value"),
				     optname(opt, flags));
		*(int *)opt->value = strtol(arg, (char **)&s, 10);
		if (*s)
			return error(_("%s expects a numerical value"),
				     optname(opt, flags));
		return 0;

	case OPTION_MAGNITUDE:
		if (unset) {
			*(unsigned long *)opt->value = 0;
			return 0;
		}
		if (opt->flags & PARSE_OPT_OPTARG && !p->opt) {
			*(unsigned long *)opt->value = opt->defval;
			return 0;
		}
		if (get_arg(p, opt, flags, &arg))
			return -1;
		if (!git_parse_ulong(arg, opt->value))
			return error(_("%s expects a non-negative integer value"
				       " with an optional k/m/g suffix"),
				     optname(opt, flags));
		return 0;

	default:
		BUG("opt->type %d should not happen", opt->type);
	}
}

static enum parse_opt_result parse_short_opt(struct parse_opt_ctx_t *p,
					     const struct option *options)
{
	const struct option *all_opts = options;
	const struct option *numopt = NULL;

	for (; options->type != OPTION_END; options++) {
		if (options->short_name == *p->opt) {
			p->opt = p->opt[1] ? p->opt + 1 : NULL;
			return get_value(p, options, all_opts, OPT_SHORT);
		}

		/*
		 * Handle the numerical option later, explicit one-digit
		 * options take precedence over it.
		 */
		if (options->type == OPTION_NUMBER)
			numopt = options;
	}
	if (numopt && isdigit(*p->opt)) {
		size_t len = 1;
		char *arg;
		int rc;

		while (isdigit(p->opt[len]))
			len++;
		arg = xmemdupz(p->opt, len);
		p->opt = p->opt[len] ? p->opt + len : NULL;
		if (numopt->callback)
			rc = (*numopt->callback)(numopt, arg, 0) ? (-1) : 0;
		else
			rc = (*numopt->ll_callback)(p, numopt, arg, 0);
		free(arg);
		return rc;
	}
	return PARSE_OPT_UNKNOWN;
}

static enum parse_opt_result parse_long_opt(
	struct parse_opt_ctx_t *p, const char *arg,
	const struct option *options)
{
	const struct option *all_opts = options;
	const char *arg_end = strchrnul(arg, '=');
	const struct option *abbrev_option = NULL, *ambiguous_option = NULL;
	enum opt_parsed abbrev_flags = OPT_LONG, ambiguous_flags = OPT_LONG;
	const char *test_var = "GIT_TEST_DISALLOW_ABBREVIATED_OPTIONS";
	static int no_abbrev = -1;

	if (no_abbrev < 0)
		no_abbrev = git_env_bool(test_var, 0);

	for (; options->type != OPTION_END; options++) {
		const char *rest, *long_name = options->long_name;
		enum opt_parsed flags = OPT_LONG, opt_flags = OPT_LONG;

		if (!long_name)
			continue;

again:
		if (!skip_prefix(arg, long_name, &rest))
			rest = NULL;
		if (!rest) {
			/* abbreviated? */
			if (!(options->flags & PARSE_OPT_NO_ABBREV) &&
			    !strncmp(long_name, arg, arg_end - arg)) {
is_abbreviated:
				if (abbrev_option &&
				    !(options->flags & PARSE_OPT_NO_AMBIG)) {
					/*
					 * If this is abbreviated, it is
					 * ambiguous. So when there is no
					 * exact match later, we need to
					 * error out.
					 */
					ambiguous_option = abbrev_option;
					ambiguous_flags = abbrev_flags;
				}
				if (!(flags & OPT_UNSET) && *arg_end)
					p->opt = arg_end + 1;
				abbrev_option = options;
				abbrev_flags = flags ^ opt_flags;
				continue;
			}
			/* negation allowed? */
			if (options->flags & PARSE_OPT_NONEG)
				continue;
			/* negated and abbreviated very much? */
			if (starts_with("no-", arg)) {
				flags |= OPT_UNSET;
				goto is_abbreviated;
			}
			/* negated? */
			if (!starts_with(arg, "no-")) {
				if (skip_prefix(long_name, "no-", &long_name)) {
					opt_flags |= OPT_UNSET;
					goto again;
				}
				continue;
			}
			flags |= OPT_UNSET;
			if (!skip_prefix(arg + 3, long_name, &rest)) {
				/* abbreviated and negated? */
				if (starts_with(long_name, arg + 3))
					goto is_abbreviated;
				else
					continue;
			}
		}
		if (*rest) {
			if (*rest != '=')
				continue;
			p->opt = rest + 1;
		}
		return get_value(p, options, all_opts, flags ^ opt_flags);
	}
	if (ambiguous_option)
		error(_("ambiguous option: %s "
			"(could be --%s%s or --%s%s)"),
			arg,
			(ambiguous_flags & OPT_UNSET) ?  "no-" : "",
			ambiguous_option->long_name,
			(abbrev_flags & OPT_UNSET) ?  "no-" : "",
			abbrev_option->long_name);

	if (no_abbrev && abbrev_option)
		BUG("disallowed abbreviated option '%.*s'. "
		    "To test abbreviated options use %s=false",
		    (int)(arg_end - arg), arg, test_var);

	if (no_abbrev && ambiguous_option)
		BUG("dying on ambiguous option per 'error' above. "
		    "To test abbreviated options use %s=false",
		    test_var);

	if (ambiguous_option)
		return PARSE_OPT_HELP;

	if (abbrev_option)
		return get_value(p, abbrev_option, all_opts, abbrev_flags);
	return PARSE_OPT_UNKNOWN;
}

static enum parse_opt_result parse_nodash_opt(struct parse_opt_ctx_t *p,
					      const char *arg,
					      const struct option *options)
{
	const struct option *all_opts = options;

	for (; options->type != OPTION_END; options++) {
		if (!(options->flags & PARSE_OPT_NODASH))
			continue;
		if (options->short_name == arg[0] && arg[1] == '\0')
			return get_value(p, options, all_opts, OPT_SHORT);
	}
	return PARSE_OPT_ERROR;
}

static void check_typos(const char *arg, const struct option *options)
{
	if (strlen(arg) < 3)
		return;

	if (starts_with(arg, "no-")) {
		error(_("did you mean `--%s` (with two dashes)?"), arg);
		exit(129);
	}

	for (; options->type != OPTION_END; options++) {
		if (!options->long_name)
			continue;
		if (starts_with(options->long_name, arg)) {
			error(_("did you mean `--%s` (with two dashes)?"), arg);
			exit(129);
		}
	}
}

static void parse_options_alter_flags(struct parse_opt_ctx_t *ctx)
{
	if (HAS_MULTI_BITS(ctx->flags & (PARSE_OPT_NO_INTERNAL_HELP |
					 PARSE_OPT_INTERNAL_HELP_ON_ONE_ARG)))
		BUG("set only one of PARSE_OPT_{NO_INTERNAL_HELP,INTERNAL_HELP_ON_ONE_ARG}");
	if (ctx->flags & PARSE_OPT_INTERNAL_HELP_ON_ONE_ARG)
		ctx->flags |= PARSE_OPT_NO_INTERNAL_HELP;
}

static void parse_options_check_flags(const struct option *opts,
				      const enum parse_opt_flags flags)
{
	int err = 0;
	int saw_help_opt = 0;

	if ((flags & PARSE_OPT_KEEP_UNKNOWN) &&
	    (flags & PARSE_OPT_STOP_AT_NON_OPTION) &&
	    !(flags & PARSE_OPT_ONE_SHOT))
		BUG("STOP_AT_NON_OPTION and KEEP_UNKNOWN don't go together");
	if ((flags & PARSE_OPT_ONE_SHOT) &&
	    (flags & PARSE_OPT_KEEP_ARGV0))
		BUG("Can't keep argv0 if you don't have it");

	for (; opts->type != OPTION_END; opts++) {
		if (!(flags & PARSE_OPT_KEEP_UNKNOWN) &&
		    (opts->flags & PARSE_OPT_NO_ABBREV))
			err |= optbug(opts, "parse_options() KEEP_UNKNOWN "
				      "flag and option NO_ABBREV flag are "
				      "are incompatible");

		if (!(flags & PARSE_OPT_REV_PARSE_PARSEOPT)) {
			if (opts->flags & PARSE_OPT_HIDDEN &&
			    opts->help)
				err |= optbug(opts, "defines help, but is hidden");

			if (opts->flags & PARSE_OPT_HIDDEN &&
			    opts->argh)
				err |= optbug(opts, "defines argument help, but is hidden");
		}

		if ((opts->short_name && opts->short_name == 'h') ||
		    (opts->long_name && (!strcmp(opts->long_name, "help") ||
					 !strcmp(opts->long_name, "help-all"))))
			saw_help_opt = 1;

	}
	if (!(flags & PARSE_OPT_REV_PARSE_PARSEOPT) &&
	    !(flags & PARSE_OPT_NO_INTERNAL_HELP) &&
	    saw_help_opt)
		BUG("set PARSE_OPT_NO_INTERNAL_HELP if using custom help options");

	if (err)
		exit(128);
}

static void parse_options_check(const struct option *opts)
{
	int err = 0;
	char short_opts[128];
	struct string_list long_opts = STRING_LIST_INIT_NODUP;

	memset(short_opts, '\0', sizeof(short_opts));
	for (; opts->type != OPTION_END; opts++) {
		if ((opts->flags & PARSE_OPT_NO_ABBREV) &&
		    (opts->flags & PARSE_OPT_NO_AMBIG))
			err |= optbug(opts, "uses incompatible flags "
				      "NO_ABBREV and NO_AMBIG");
		if ((opts->flags & PARSE_OPT_LASTARG_DEFAULT) &&
		    (opts->flags & PARSE_OPT_OPTARG))
			err |= optbug(opts, "uses incompatible flags "
					"LASTARG_DEFAULT and OPTARG");
		if (opts->short_name) {
			if (0x7F <= opts->short_name)
				err |= optbug(opts, "invalid short name");
			else if (iscntrl(opts->short_name))
				err |= optbug(opts, "invalid short name");
			else if (short_opts[opts->short_name]++)
				err |= optbug(opts, "short name already used");
		}
		if (opts->long_name) {
			if (string_list_has_string(&long_opts, opts->long_name))
				err |= optbug(opts, "long name already used");
			string_list_insert(&long_opts, opts->long_name);
		}
		if (opts->flags & PARSE_OPT_NODASH &&
		    ((opts->flags & PARSE_OPT_OPTARG) ||
		     !(opts->flags & PARSE_OPT_NOARG) ||
		     !(opts->flags & PARSE_OPT_NONEG) ||
		     opts->long_name))
			err |= optbug(opts, "uses feature "
					"not supported for dashless options");

		switch (opts->type) {
		case OPTION_COUNTUP:
		case OPTION_BIT:
		case OPTION_NEGBIT:
		case OPTION_SET_INT:
		case OPTION_NUMBER:
			if ((opts->flags & PARSE_OPT_OPTARG) ||
			    !(opts->flags & PARSE_OPT_NOARG))
				err |= optbug(opts, "should not accept an argument");
			break;
		case OPTION_CALLBACK:
			if (!opts->callback && !opts->ll_callback)
				BUG("OPTION_CALLBACK needs one callback");
			if (opts->callback && opts->ll_callback)
				BUG("OPTION_CALLBACK can't have two callbacks");
			break;
		case OPTION_LOWLEVEL_CALLBACK:
			if (!opts->ll_callback)
				BUG("OPTION_LOWLEVEL_CALLBACK needs a callback");
			if (opts->callback)
				BUG("OPTION_LOWLEVEL_CALLBACK needs no high level callback");
			break;
		default:
			; /* ok. (usually accepts an argument) */
		}
		switch (opts->type) {
		case OPTION_GROUP:
			if (!opts->help)
				BUG("OPTION_GROUP must have a non-NULL 'help'");
			if (!*opts->help)
				break;
			if (!isupper(opts->help[0]))
				err |= optbug(opts, "must start with upper-case");
			if (ends_with(opts->help, ".") ||
			    ends_with(opts->help, ":"))
				err |= optbug(opts, "should not end with a period ('.') or colon (':')");
			break;
		default:
		{
			const char *const help = opts->help;
			const char *const fmt = "help should not %s: '%s'";
			const char *why;

			if (!help)
				break;
			if (*help && isupper(*help) &&
			    !(help[1] && isupper(help[1]))) {
				why = "start with a capital letter";
				err |= optbug(opts, xstrfmt(fmt, why, help));
			}
			if (!ends_with(help, "...") &&
			    ends_with(help, ".")) {
				why = "end with a dot";
				err |= optbug(opts, xstrfmt(fmt, why, help));
			}
			break;
		}
		}
		if (opts->argh &&
		    strcspn(opts->argh, " _") != strlen(opts->argh))
			err |= optbug(opts, "multi-word argh should use dash to separate words");
	}
	string_list_clear(&long_opts, 0);
	if (err)
		exit(128);
}

void parse_options_start(struct parse_opt_ctx_t *ctx,
			 int argc, const char **argv, const char *prefix,
			 const struct option *options,
			 enum parse_opt_flags flags)
{
	ctx->argc = argc;
	ctx->argv = argv;
	if (!(flags & PARSE_OPT_ONE_SHOT)) {
		ctx->argc--;
		ctx->argv++;
	}
	ctx->total = ctx->argc;
	ctx->out   = argv;
	ctx->prefix = prefix;
	ctx->cpidx = ((flags & PARSE_OPT_KEEP_ARGV0) != 0);
	ctx->flags = flags;
	parse_options_alter_flags(ctx);
	parse_options_check_flags(options, ctx->flags);
	parse_options_check(options);
}

static void show_negated_gitcomp(const struct option *opts, int show_all,
				 int nr_noopts)
{
	int printed_dashdash = 0;

	for (; opts->type != OPTION_END; opts++) {
		int has_unset_form = 0;
		const char *name;

		if (!opts->long_name)
			continue;
		if (!show_all &&
			(opts->flags & (PARSE_OPT_HIDDEN | PARSE_OPT_NOCOMPLETE)))
			continue;
		if (opts->flags & PARSE_OPT_NONEG)
			continue;

		switch (opts->type) {
		case OPTION_STRING:
		case OPTION_FILENAME:
		case OPTION_INTEGER:
		case OPTION_MAGNITUDE:
		case OPTION_CALLBACK:
		case OPTION_BIT:
		case OPTION_NEGBIT:
		case OPTION_COUNTUP:
		case OPTION_SET_INT:
			has_unset_form = 1;
			break;
		default:
			break;
		}
		if (!has_unset_form)
			continue;

		if (skip_prefix(opts->long_name, "no-", &name)) {
			if (nr_noopts < 0)
				printf(" --%s", name);
		} else if (nr_noopts >= 0) {
			if (nr_noopts && !printed_dashdash) {
				printf(" --");
				printed_dashdash = 1;
			}
			printf(" --no-%s", opts->long_name);
			nr_noopts++;
		}
	}
}

static int show_gitcomp(const struct option *opts, int show_all)
{
	const struct option *original_opts = opts;
	int nr_noopts = 0;

	for (; opts->type != OPTION_END; opts++) {
		const char *suffix = "";

		if (!opts->long_name)
			continue;
		if (!show_all &&
			(opts->flags & (PARSE_OPT_HIDDEN | PARSE_OPT_NOCOMPLETE)))
			continue;

		switch (opts->type) {
		case OPTION_GROUP:
			continue;
		case OPTION_STRING:
		case OPTION_FILENAME:
		case OPTION_INTEGER:
		case OPTION_MAGNITUDE:
		case OPTION_CALLBACK:
			if (opts->flags & PARSE_OPT_NOARG)
				break;
			if (opts->flags & PARSE_OPT_OPTARG)
				break;
			if (opts->flags & PARSE_OPT_LASTARG_DEFAULT)
				break;
			suffix = "=";
			break;
		default:
			break;
		}
		if (opts->flags & PARSE_OPT_COMP_ARG)
			suffix = "=";
		if (starts_with(opts->long_name, "no-"))
			nr_noopts++;
		printf(" --%s%s", opts->long_name, suffix);
	}
	show_negated_gitcomp(original_opts, show_all, -1);
	show_negated_gitcomp(original_opts, show_all, nr_noopts);
	fputc('\n', stdout);
	return PARSE_OPT_COMPLETE;
}

static enum parse_opt_result usage_with_options_internal(struct parse_opt_ctx_t *,
							 const char * const *,
							 const struct option *,
							 int, int);

enum parse_opt_result parse_options_step(struct parse_opt_ctx_t *ctx,
					 const struct option *options,
					 const char * const usagestr[])
{
	int internal_help = !(ctx->flags & PARSE_OPT_NO_INTERNAL_HELP);
	int internal_help_one_h = ctx->flags & PARSE_OPT_INTERNAL_HELP_ON_ONE_ARG;

	/* we must reset ->opt, unknown short option leave it dangling */
	ctx->opt = NULL;

	for (; ctx->argc; ctx->argc--, ctx->argv++) {
		const char *arg = ctx->argv[0];

		if (ctx->flags & PARSE_OPT_ONE_SHOT &&
		    ctx->argc != ctx->total)
			break;

		if (*arg != '-' || !arg[1]) {
			if (parse_nodash_opt(ctx, arg, options) == 0)
				continue;
			if (ctx->flags & PARSE_OPT_STOP_AT_NON_OPTION)
				return PARSE_OPT_NON_OPTION;
			ctx->out[ctx->cpidx++] = ctx->argv[0];
			continue;
		}

		/*
		 * A "-h" option asks for help, except for "show-ref"
		 * et al, which treat a single "-h" differently.
		 */
		if ((internal_help ||
		     (internal_help_one_h && ctx->total == 1)) &&
		    !strcmp(arg + 1, "h"))
			goto show_usage;

		/*
		 * lone --git-completion-helper and --git-completion-helper-all
		 * are asked by git-completion.bash
		 */
		if (ctx->total == 1 && !strcmp(arg, "--git-completion-helper"))
			return show_gitcomp(options, 0);
		if (ctx->total == 1 && !strcmp(arg, "--git-completion-helper-all"))
			return show_gitcomp(options, 1);

		if (arg[1] != '-') {
			ctx->opt = arg + 1;
			switch (parse_short_opt(ctx, options)) {
			case PARSE_OPT_ERROR:
				return PARSE_OPT_ERROR;
			case PARSE_OPT_UNKNOWN:
				if (ctx->opt)
					check_typos(arg + 1, options);
				if (internal_help && *ctx->opt == 'h')
					goto show_usage;
				goto unknown;
			case PARSE_OPT_NON_OPTION:
			case PARSE_OPT_HELP:
			case PARSE_OPT_COMPLETE:
				BUG("parse_short_opt() cannot return these");
			case PARSE_OPT_DONE:
				break;
			}
			if (ctx->opt)
				check_typos(arg + 1, options);
			while (ctx->opt) {
				switch (parse_short_opt(ctx, options)) {
				case PARSE_OPT_ERROR:
					return PARSE_OPT_ERROR;
				case PARSE_OPT_UNKNOWN:
					if (internal_help && *ctx->opt == 'h')
						goto show_usage;

					/* fake a short option thing to hide the fact that we may have
					 * started to parse aggregated stuff
					 *
					 * This is leaky, too bad.
					 */
					ctx->argv[0] = xstrdup(ctx->opt - 1);
					*(char *)ctx->argv[0] = '-';
					goto unknown;
				case PARSE_OPT_NON_OPTION:
				case PARSE_OPT_COMPLETE:
				case PARSE_OPT_HELP:
					BUG("parse_short_opt() cannot return these");
				case PARSE_OPT_DONE:
					break;
				}
			}
			continue;
		}

		if (!arg[2] /* "--" */ ||
		    !strcmp(arg + 2, "end-of-options")) {
			if (!(ctx->flags & PARSE_OPT_KEEP_DASHDASH)) {
				ctx->argc--;
				ctx->argv++;
			}
			break;
		}

		if (internal_help && !strcmp(arg + 2, "help-all"))
			return usage_with_options_internal(ctx, usagestr, options, 1, 0);
		if (internal_help && !strcmp(arg + 2, "help"))
			goto show_usage;
		switch (parse_long_opt(ctx, arg + 2, options)) {
		case PARSE_OPT_ERROR:
			return PARSE_OPT_ERROR;
		case PARSE_OPT_UNKNOWN:
			goto unknown;
		case PARSE_OPT_HELP:
			goto show_usage;
		case PARSE_OPT_NON_OPTION:
		case PARSE_OPT_COMPLETE:
			BUG("parse_long_opt() cannot return these");
		case PARSE_OPT_DONE:
			break;
		}
		continue;
unknown:
		if (ctx->flags & PARSE_OPT_ONE_SHOT)
			break;
		if (!(ctx->flags & PARSE_OPT_KEEP_UNKNOWN))
			return PARSE_OPT_UNKNOWN;
		ctx->out[ctx->cpidx++] = ctx->argv[0];
		ctx->opt = NULL;
	}
	return PARSE_OPT_DONE;

 show_usage:
	return usage_with_options_internal(ctx, usagestr, options, 0, 0);
}

int parse_options_end(struct parse_opt_ctx_t *ctx)
{
	if (ctx->flags & PARSE_OPT_ONE_SHOT)
		return ctx->total - ctx->argc;

	MOVE_ARRAY(ctx->out + ctx->cpidx, ctx->argv, ctx->argc);
	ctx->out[ctx->cpidx + ctx->argc] = NULL;
	return ctx->cpidx + ctx->argc;
}

int parse_options(int argc, const char **argv,
		  const char *prefix,
		  const struct option *options,
		  const char * const usagestr[],
		  enum parse_opt_flags flags)
{
	struct parse_opt_ctx_t ctx = { 0 };

	parse_options_start(&ctx, argc, argv, prefix, options, flags);
	switch (parse_options_step(&ctx, options, usagestr)) {
	case PARSE_OPT_HELP:
	case PARSE_OPT_ERROR:
		exit(129);
	case PARSE_OPT_COMPLETE:
		exit(0);
	case PARSE_OPT_NON_OPTION:
	case PARSE_OPT_DONE:
		break;
	case PARSE_OPT_UNKNOWN:
		if (ctx.argv[0][1] == '-') {
			error(_("unknown option `%s'"), ctx.argv[0] + 2);
		} else if (isascii(*ctx.opt)) {
			error(_("unknown switch `%c'"), *ctx.opt);
		} else {
			error(_("unknown non-ascii option in string: `%s'"),
			      ctx.argv[0]);
		}
		usage_with_options(usagestr, options);
	}

	precompose_argv_prefix(argc, argv, NULL);
	return parse_options_end(&ctx);
}

static int usage_argh(const struct option *opts, FILE *outfile)
{
	const char *s;
	int literal = (opts->flags & PARSE_OPT_LITERAL_ARGHELP) ||
		!opts->argh || !!strpbrk(opts->argh, "()<>[]|");
	if (opts->flags & PARSE_OPT_OPTARG)
		if (opts->long_name)
			s = literal ? "[=%s]" : "[=<%s>]";
		else
			s = literal ? "[%s]" : "[<%s>]";
	else
		s = literal ? " %s" : " <%s>";
	return utf8_fprintf(outfile, s, opts->argh ? _(opts->argh) : _("..."));
}

#define USAGE_OPTS_WIDTH 24
#define USAGE_GAP         2

static enum parse_opt_result usage_with_options_internal(struct parse_opt_ctx_t *ctx,
							 const char * const *usagestr,
							 const struct option *opts,
							 int full, int err)
{
	FILE *outfile = err ? stderr : stdout;
	int need_newline;

	const char *usage_prefix = _("usage: %s");
	/*
	 * The translation could be anything, but we can count on
	 * msgfmt(1)'s --check option to have asserted that "%s" is in
	 * the translation. So compute the length of the "usage: "
	 * part. We are assuming that the translator wasn't overly
	 * clever and used e.g. "%1$s" instead of "%s", there's only
	 * one "%s" in "usage_prefix" above, so there's no reason to
	 * do so even with a RTL language.
	 */
	size_t usage_len = strlen(usage_prefix) - strlen("%s");
	/*
	 * TRANSLATORS: the colon here should align with the
	 * one in "usage: %s" translation.
	 */
	const char *or_prefix = _("   or: %s");
	/*
	 * TRANSLATORS: You should only need to translate this format
	 * string if your language is a RTL language (e.g. Arabic,
	 * Hebrew etc.), not if it's a LTR language (e.g. German,
	 * Russian, Chinese etc.).
	 *
	 * When a translated usage string has an embedded "\n" it's
	 * because options have wrapped to the next line. The line
	 * after the "\n" will then be padded to align with the
	 * command name, such as N_("git cmd [opt]\n<8
	 * spaces>[opt2]"), where the 8 spaces are the same length as
	 * "git cmd ".
	 *
	 * This format string prints out that already-translated
	 * line. The "%*s" is whitespace padding to account for the
	 * padding at the start of the line that we add in this
	 * function. The "%s" is a line in the (hopefully already
	 * translated) N_() usage string, which contained embedded
	 * newlines before we split it up.
	 */
	const char *usage_continued = _("%*s%s");
	const char *prefix = usage_prefix;
	int saw_empty_line = 0;

	if (!usagestr)
		return PARSE_OPT_HELP;

	if (!err && ctx && ctx->flags & PARSE_OPT_SHELL_EVAL)
		fprintf(outfile, "cat <<\\EOF\n");

	while (*usagestr) {
		const char *str = _(*usagestr++);
		struct string_list list = STRING_LIST_INIT_DUP;
		unsigned int j;

		if (!saw_empty_line && !*str)
			saw_empty_line = 1;

		string_list_split(&list, str, '\n', -1);
		for (j = 0; j < list.nr; j++) {
			const char *line = list.items[j].string;

			if (saw_empty_line && *line)
				fprintf_ln(outfile, _("    %s"), line);
			else if (saw_empty_line)
				fputc('\n', outfile);
			else if (!j)
				fprintf_ln(outfile, prefix, line);
			else
				fprintf_ln(outfile, usage_continued,
					   (int)usage_len, "", line);
		}
		string_list_clear(&list, 0);

		prefix = or_prefix;
	}

	need_newline = 1;

	for (; opts->type != OPTION_END; opts++) {
		size_t pos;
		int pad;

		if (opts->type == OPTION_GROUP) {
			fputc('\n', outfile);
			need_newline = 0;
			if (*opts->help)
				fprintf(outfile, "%s\n", _(opts->help));
			continue;
		}
		if (!full && (opts->flags & PARSE_OPT_HIDDEN))
			continue;

		if (need_newline) {
			fputc('\n', outfile);
			need_newline = 0;
		}

		pos = fprintf(outfile, "    ");
		if (opts->short_name) {
			if (opts->flags & PARSE_OPT_NODASH)
				pos += fprintf(outfile, "%c", opts->short_name);
			else
				pos += fprintf(outfile, "-%c", opts->short_name);
		}
		if (opts->long_name && opts->short_name)
			pos += fprintf(outfile, ", ");
		if (opts->long_name)
			pos += fprintf(outfile, "--%s", opts->long_name);
		if (opts->type == OPTION_NUMBER)
			pos += utf8_fprintf(outfile, _("-NUM"));

		if ((opts->flags & PARSE_OPT_LITERAL_ARGHELP) ||
		    !(opts->flags & PARSE_OPT_NOARG))
			pos += usage_argh(opts, outfile);

		if (pos <= USAGE_OPTS_WIDTH)
			pad = USAGE_OPTS_WIDTH - pos;
		else {
			fputc('\n', outfile);
			pad = USAGE_OPTS_WIDTH;
		}
		fprintf(outfile, "%*s%s\n", pad + USAGE_GAP, "", _(opts->help));
	}
	fputc('\n', outfile);

	if (!err && ctx && ctx->flags & PARSE_OPT_SHELL_EVAL)
		fputs("EOF\n", outfile);

	return PARSE_OPT_HELP;
}

void NORETURN usage_with_options(const char * const *usagestr,
			const struct option *opts)
{
	parse_options_check(opts);
	usage_with_options_internal(NULL, usagestr, opts, 0, 1);
	exit(129);
}

void NORETURN usage_msg_opt(const char *msg,
		   const char * const *usagestr,
		   const struct option *options)
{
	die_message("%s\n", msg); /* The extra \n is intentional */
	usage_with_options(usagestr, options);
}

void NORETURN usage_msg_optf(const char * const fmt,
			     const char * const *usagestr,
			     const struct option *options, ...)
{
	struct strbuf msg = STRBUF_INIT;
	va_list ap;
	va_start(ap, options);
	strbuf_vaddf(&msg, fmt, ap);
	va_end(ap);

	usage_msg_opt(msg.buf, usagestr, options);
}

void die_for_incompatible_opt4(int opt1, const char *opt1_name,
			       int opt2, const char *opt2_name,
			       int opt3, const char *opt3_name,
			       int opt4, const char *opt4_name)
{
	int count = 0;
	const char *options[4];

	if (opt1)
		options[count++] = opt1_name;
	if (opt2)
		options[count++] = opt2_name;
	if (opt3)
		options[count++] = opt3_name;
	if (opt4)
		options[count++] = opt4_name;
	switch (count) {
	case 4:
		die(_("options '%s', '%s', '%s', and '%s' cannot be used together"),
		    opt1_name, opt2_name, opt3_name, opt4_name);
		break;
	case 3:
		die(_("options '%s', '%s', and '%s' cannot be used together"),
		    options[0], options[1], options[2]);
		break;
	case 2:
		die(_("options '%s' and '%s' cannot be used together"),
		    options[0], options[1]);
		break;
	default:
		break;
	}
}
