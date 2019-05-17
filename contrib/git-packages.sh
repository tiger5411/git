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
alpine	main/git	https://git.alpinelinux.org/aports
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
git commit -m"Packages in git repositories"
git checkout

# Special snowflakes
mkdir AIX
aix_url='https://public.dhe.ibm.com/aix/freeSoftware/aixtoolbox/SRPMS/git/'
aix_rpm=$(w3m -dump $aix_url  | grep -o git-.*rpm | sort -Vr | head -n 1)
wget $aix_url/$aix_rpm -O AIX/src.rpm
(
    cd AIX &&
    rpm2cpio *.rpm | cpio -idmv &&
    rm -v *.tar.gz *.tar.sign *.tar.xz *.rpm
)
git add AIX
git commit -m"IBM's AIX package"

#rm -rfv $dir
