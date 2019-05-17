#!/bin/sh

set -eu

dir=$(mktemp -d /tmp/git-packages-XXXXX)
echo INFO: Working in $dir >&2

cd $dir


cat >repositories.txt <<-EOF
freebsd-ports	devel/git	https://github.com/freebsd/freebsd-ports.git
openbsd-ports	devel/git	https://github.com/openbsd/ports.git
netbsd-pkgsrc	devel/git-base	https://github.com/NetBSD/pkgsrc.git
fedora	.	https://src.fedoraproject.org/rpms/git
gentoo	dev-vcs/git	https://github.com/gentoo/gentoo.git
arch	git/trunk	https://git.archlinux.org/svntogit/packages.git
nix	pkgs/applications/version-management/git-and-tools/git	https://github.com/NixOS/nixpkgs.git
EOF

git init
while read line
do
	os=$(echo $line | cut -d" " -f1)
	path=$(echo $line | cut -d" " -f2)
	test $path = "." && path=
	url=$(echo $line | cut -d" " -f3)

	git remote add --no-tags $os $url
	git config remote.$os.fetch "+HEAD:refs/$os/HEAD"
done <repositories.txt

parallel 'git fetch {}' ::: $(git remote)

>trees.txt
while read line
do
	os=$(echo $line | cut -d" " -f1)
	path=$(echo $line | cut -d" " -f2)
	if test $path = "."
	then
	    path=
	fi

	tree=$(git rev-parse refs/$os/HEAD:$path)
	printf "040000 tree $tree\t$os\n"
done <repositories.txt >>trees.txt

root=$(git mktree <trees.txt)
git read-tree $root
git commit -m"snap"
git checkout

#rm -rfv $dir
