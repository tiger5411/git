#!/bin/sh

set -eu

dir=$(mktemp -d /tmp/git-packages-XXXXX)
echo INFO: Working in $dir >&2

cd $dir


cat >repositories.txt <<-EOF
freebsd-ports	devel/git	https://github.com/freebsd/freebsd-ports.git
openbsd-ports	devel/git	https://github.com/openbsd/ports.git
netbsd-pkgsrc	devel/git-base	https://github.com/NetBSD/pkgsrc.git
dragonflybsd-dports	devel/git	https://github.com/DragonFlyBSD/DPorts.git
fedora	.	https://src.fedoraproject.org/rpms/git
debian	debian	https://repo.or.cz/git/debian.git
gentoo	dev-vcs/git	https://github.com/gentoo/gentoo.git
arch	git/trunk	https://git.archlinux.org/svntogit/packages.git
nix	pkgs/applications/version-management/git-and-tools/git	https://github.com/NixOS/nixpkgs.git
alpine	main/git	https://git.alpinelinux.org/aports
git_osx_installer	.	https://github.com/timcharper/git_osx_installer.git
homebrew-core	Formula/git.rb	https://github.com/Homebrew/homebrew-core.git
macports-ports	devel/git	https://github.com/macports/macports-ports.git
EOF

# Init!
git init

# Make a dummy history to feed to --negotiation-tip because it has #
# no support for "don't negotiate on the basis of existing history".
blob=$(echo empty | git hash-object -w --stdin)
tree=$(perl -wE 'say "100644 blob $ARGV[0]\tempty"' $blob | git mktree)
commit=$(git commit-tree $tree -m "empty")
git branch -f empty $commit

# Setup repos
>os.txt
while read line
do
	os=$(echo $line | cut -d" " -f1)
	path=$(echo $line | cut -d" " -f2)
	test $path = "." && path=
	url=$(echo $line | cut -d" " -f3)

	git init --bare repos/$os.git
	git -C repos/$os.git remote add --no-tags $os $url
	git -C repos/$os.git config remote.$os.fetch "+HEAD:refs/$os/HEAD"
	echo $os >>os.txt
done <repositories.txt

# This is all in different repos because --depth=1 (has shallow lock
# of some sort) concurrency sucks.
parallel --jobs=100% 'git -C repos/{}.git fetch {} --depth=1' :::: os.txt

# Find tips of all the "repos"
>trees.txt
while read line
do
	os=$(echo $line | cut -d" " -f1)
	path=$(echo $line | cut -d" " -f2)
	if test $path = "."
	then
	    path=
	fi

	object=$(git -C repos/$os.git rev-parse refs/$os/HEAD:$path)
	type=$(git -C repos/$os.git cat-file -t $object)
	case "$type" in
	tree)
		printf "040000 tree $object\t$os\n"
		;;
	blob)
		printf "100644 blob $object\t$os\n"
		;;
	*)
		echo ERROR: Unknown type for $object
		exit 1
	esac
done <repositories.txt >>trees.txt

# Add all these as alternates to make them addressable
>.git/objects/info/alternates
for os in $(cat os.txt)
do 
    echo $PWD/repos/$os.git/objects >> .git/objects/info/alternates
done

# Create a root tree
tree=$(git mktree <trees.txt)
git read-tree $tree
git commit -m"Packages in git repositories"
git reset --hard

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

echo INFO: Dropped in $dir >&2

#rm -rfv $dir
