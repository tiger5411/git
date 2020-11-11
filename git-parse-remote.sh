# This is a shell library to calculate the remote repository and
# upstream branch that should be pulled by "git pull" from the current
# branch.

get_default_remote () {
	curr_branch=$(git symbolic-ref -q HEAD)
	curr_branch="${curr_branch#refs/heads/}"
	origin=$(git config --get "branch.$curr_branch.remote")
	echo ${origin:-origin}
}
