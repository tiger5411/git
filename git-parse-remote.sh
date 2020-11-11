# This is a shell library to calculate the remote repository and
# upstream branch that should be pulled by "git pull" from the current
# branch.

get_default_remote () {
	curr_branch=$(git symbolic-ref -q HEAD)
	curr_branch="${curr_branch#refs/heads/}"
	origin=$(git config --get "branch.$curr_branch.remote")
	echo ${origin:-origin}
}

get_remote_merge_branch () {
	case "$#" in
	0|1)
	    origin="$1"
	    default=$(get_default_remote)
	    test -z "$origin" && origin=$default
	    curr_branch=$(git symbolic-ref -q HEAD) &&
	    [ "$origin" = "$default" ] &&
	    echo $(git for-each-ref --format='%(upstream)' $curr_branch)
	    ;;
	*)
	    repo=$1
	    shift
	    ref=$1
	    # FIXME: It should return the tracking branch
	    #        Currently only works with the default mapping
	    case "$ref" in
	    +*)
		ref=$(expr "z$ref" : 'z+\(.*\)')
		;;
	    esac
	    expr "z$ref" : 'z.*:' >/dev/null || ref="${ref}:"
	    remote=$(expr "z$ref" : 'z\([^:]*\):')
	    case "$remote" in
	    '' | HEAD ) remote=HEAD ;;
	    heads/*) remote=${remote#heads/} ;;
	    refs/heads/*) remote=${remote#refs/heads/} ;;
	    refs/* | tags/* | remotes/* ) remote=
	    esac
	    [ -n "$remote" ] && case "$repo" in
		.)
		    echo "refs/heads/$remote"
		    ;;
		*)
		    echo "refs/remotes/$repo/$remote"
		    ;;
	    esac
	esac
}
