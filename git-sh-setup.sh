# This shell scriplet is meant to be included by other shell scripts
# to set up some variables pointing at the normal git directories and
# a few helper shell functions.

# Having this variable in your environment would break scripts because
# you would cause "cd" to be taken to unexpected places.  If you
# like CDPATH, define it for your interactive shell sessions without
# exporting it.
# But we protect ourselves from such a user mistake nevertheless.
unset CDPATH

# Similarly for IFS, but some shells (e.g. FreeBSD 7.2) are buggy and
# do not equate an unset IFS with IFS with the default, so here is
# an explicit SP HT LF.
IFS=' 	
'

git_broken_path_fix () {
	case ":$PATH:" in
	*:$1:*) : ok ;;
	*)
		PATH=$(
			SANE_TOOL_PATH="$1"
			IFS=: path= sep=
			set x $PATH
			shift
			for elem
			do
				case "$SANE_TOOL_PATH:$elem" in
				(?*:/bin | ?*:/usr/bin)
					path="$path$sep$SANE_TOOL_PATH"
					sep=:
					SANE_TOOL_PATH=
				esac
				path="$path$sep$elem"
				sep=:
			done
			echo "$path"
		)
		;;
	esac
}

# @@BROKEN_PATH_FIX@@

# Source git-sh-i18n for gettext support.
. "$(git --exec-path)/git-sh-i18n"

die () {
	die_with_status 1 "$@"
}

die_with_status () {
	status=$1
	shift
	printf >&2 '%s\n' "$*"
	exit "$status"
}

GIT_QUIET=

say () {
	if test -z "$GIT_QUIET"
	then
		printf '%s\n' "$*"
	fi
}

if test -n "$OPTIONS_SPEC"; then
	usage() {
		"$0" -h
		exit 1
	}

	parseopt_extra=
	[ -n "$OPTIONS_KEEPDASHDASH" ] &&
		parseopt_extra="--keep-dashdash"
	[ -n "$OPTIONS_STUCKLONG" ] &&
		parseopt_extra="$parseopt_extra --stuck-long"

	eval "$(
		echo "$OPTIONS_SPEC" |
			git rev-parse --parseopt $parseopt_extra -- "$@" ||
		echo exit $?
	)"
else
	dashless=$(basename -- "$0" | sed -e 's/-/ /')
	usage() {
		die "$(eval_gettext "usage: \$dashless \$USAGE")"
	}

	if [ -z "$LONG_USAGE" ]
	then
		LONG_USAGE="$(eval_gettext "usage: \$dashless \$USAGE")"
	else
		LONG_USAGE="$(eval_gettext "usage: \$dashless \$USAGE

$LONG_USAGE")"
	fi

	case "$1" in
		-h)
		echo "$LONG_USAGE"
		case "$0" in *git-legacy-stash) exit 129;; esac
		exit
	esac
fi

sane_grep () {
	GREP_OPTIONS= LC_ALL=C grep @@SANE_TEXT_GREP@@ "$@"
}

is_bare_repository () {
	git rev-parse --is-bare-repository
}

cd_to_toplevel () {
	cdup=$(git rev-parse --show-toplevel) &&
	cd "$cdup" || {
		gettextln "Cannot chdir to \$cdup, the toplevel of the working tree" >&2
		exit 1
	}
}

require_work_tree () {
	test "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true || {
		program_name=$0
		die "$(eval_gettext "fatal: \$program_name cannot be used without a working tree.")"
	}
}

require_clean_work_tree () {
	git rev-parse --verify HEAD >/dev/null || exit 1
	git update-index -q --ignore-submodules --refresh
	err=0

	if ! git diff-files --quiet --ignore-submodules
	then
		action=$1
		case "$action" in
		rebase)
			gettextln "Cannot rebase: You have unstaged changes." >&2
			;;
		"rewrite branches")
			gettextln "Cannot rewrite branches: You have unstaged changes." >&2
			;;
		"pull with rebase")
			gettextln "Cannot pull with rebase: You have unstaged changes." >&2
			;;
		*)
			eval_gettextln "Cannot \$action: You have unstaged changes." >&2
			;;
		esac
		err=1
	fi

	if ! git diff-index --cached --quiet --ignore-submodules HEAD --
	then
		if test $err = 0
		then
			action=$1
			case "$action" in
			rebase)
				gettextln "Cannot rebase: Your index contains uncommitted changes." >&2
				;;
			"pull with rebase")
				gettextln "Cannot pull with rebase: Your index contains uncommitted changes." >&2
				;;
			*)
				eval_gettextln "Cannot \$action: Your index contains uncommitted changes." >&2
				;;
			esac
		else
		    gettextln "Additionally, your index contains uncommitted changes." >&2
		fi
		err=1
	fi

	if test $err = 1
	then
		test -n "$2" && echo "$2" >&2
		exit 1
	fi
}

# Generate a sed script to parse identities from a commit.
#
# Reads the commit from stdin, which should be in raw format (e.g., from
# cat-file or "--pretty=raw").
#
# The first argument specifies the ident line to parse (e.g., "author"), and
# the second specifies the environment variable to put it in (e.g., "AUTHOR"
# for "GIT_AUTHOR_*"). Multiple pairs can be given to parse author and
# committer.
pick_ident_script () {
	while test $# -gt 0
	do
		lid=$1; shift
		uid=$1; shift
		printf '%s' "
		/^$lid /{
			s/'/'\\\\''/g
			h
			s/^$lid "'\([^<]*\) <[^>]*> .*$/\1/'"
			s/.*/GIT_${uid}_NAME='&'/p

			g
			s/^$lid "'[^<]* <\([^>]*\)> .*$/\1/'"
			s/.*/GIT_${uid}_EMAIL='&'/p

			g
			s/^$lid "'[^<]* <[^>]*> \(.*\)$/@\1/'"
			s/.*/GIT_${uid}_DATE='&'/p
		}
		"
	done
	echo '/^$/q'
}

# Create a pick-script as above and feed it to sed. Stdout is suitable for
# feeding to eval.
parse_ident_from_commit () {
	LANG=C LC_ALL=C sed -ne "$(pick_ident_script "$@")"
}

# Parse the author from a commit given as an argument. Stdout is suitable for
# feeding to eval to set the usual GIT_* ident variables.
get_author_ident_from_commit () {
	encoding=$(git config i18n.commitencoding || echo UTF-8)
	git show -s --pretty=raw --encoding="$encoding" "$1" -- |
	parse_ident_from_commit author AUTHOR
}

# Clear repo-local GIT_* environment variables. Useful when switching to
# another repository (e.g. when entering a submodule). See also the env
# list in git_connect()
clear_local_git_env() {
	unset $(git rev-parse --local-env-vars)
}


# Platform specific tweaks to work around some commands
case $(uname -s) in
*MINGW*)
	# Windows has its own (incompatible) sort and find
	sort () {
		/usr/bin/sort "$@"
	}
	find () {
		/usr/bin/find "$@"
	}
	# git sees Windows-style pwd
	pwd () {
		builtin pwd -W
	}
	is_absolute_path () {
		case "$1" in
		[/\\]* | [A-Za-z]:*)
			return 0 ;;
		esac
		return 1
	}
	;;
*)
	is_absolute_path () {
		case "$1" in
		/*)
			return 0 ;;
		esac
		return 1
	}
esac

# Make sure we are in a valid repository of a vintage we understand,
# if we require to be in a git repository.
git_dir_init () {
	GIT_DIR=$(git rev-parse --git-dir) || exit
	if [ -z "$SUBDIRECTORY_OK" ]
	then
		test -z "$(git rev-parse --show-cdup)" || {
			exit=$?
			gettextln "You need to run this command from the toplevel of the working tree." >&2
			exit $exit
		}
	fi
	test -n "$GIT_DIR" && GIT_DIR=$(cd "$GIT_DIR" && pwd) || {
		gettextln "Unable to determine absolute path of git directory" >&2
		exit 1
	}
	: "${GIT_OBJECT_DIRECTORY="$(git rev-parse --git-path objects)"}"
}

if test -z "$NONGIT_OK"
then
	git_dir_init
fi

peel_committish () {
	case "$1" in
	:/*)
		peeltmp=$(git rev-parse --verify "$1") &&
		git rev-parse --verify "${peeltmp}^0"
		;;
	*)
		git rev-parse --verify "${1}^0"
		;;
	esac
}
