#!/bin/sh
#
# Install dependencies required to build and test Git on Linux and macOS
#

set -ex

UBUNTU_COMMON_PKGS="make libssl-dev libcurl4-openssl-dev libexpat-dev
 tcl tk gettext zlib1g-dev perl-modules liberror-perl libauthen-sasl-perl
 libemail-valid-perl libio-socket-ssl-perl libnet-smtp-ssl-perl"

case "$runs_on_pool" in
ubuntu-latest)
	# The Linux build installs the defined dependency versions below.
	# The OS X build installs much more recent versions, whichever
	# were recorded in the Homebrew database upon creating the OS X
	# image.
	# Keep that in mind when you encounter a broken OS X build!
	LINUX_P4_VERSION="16.2"
	LINUX_GIT_LFS_VERSION="1.5.2"

	P4_PATH="$HOME/custom/p4"
	GIT_LFS_PATH="$HOME/custom/git-lfs"
	export PATH="$GIT_LFS_PATH:$P4_PATH:$PATH"
	if test -n "$GITHUB_PATH"
	then
		echo "$PATH" >>"$GITHUB_PATH"
	fi

	P4WHENCE=http://filehost.perforce.com/perforce/r$LINUX_P4_VERSION
	LFSWHENCE=https://github.com/github/git-lfs/releases/download/v$LINUX_GIT_LFS_VERSION

	sudo apt-get -q update
	sudo apt-get -q -y install language-pack-is libsvn-perl apache2 \
		$UBUNTU_COMMON_PKGS $CC_PACKAGE
	mkdir --parents "$P4_PATH"
	(
		cd "$P4_PATH"
		wget --quiet "$P4WHENCE/bin.linux26x86_64/p4d"
		wget --quiet "$P4WHENCE/bin.linux26x86_64/p4"
		chmod u+x p4d
		chmod u+x p4
	)
	mkdir --parents "$GIT_LFS_PATH"
	(
		cd "$GIT_LFS_PATH"
		wget --quiet "$LFSWHENCE/git-lfs-linux-amd64-$LINUX_GIT_LFS_VERSION.tar.gz"
		tar --extract --gunzip --file "git-lfs-linux-amd64-$LINUX_GIT_LFS_VERSION.tar.gz"
		cp git-lfs-$LINUX_GIT_LFS_VERSION/git-lfs .
	)
	;;
macos-latest)
	export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
	# Uncomment this if you want to run perf tests:
	# brew install gnu-time
	brew link --force gettext
	brew install --cask --no-quarantine perforce || {
		# Update the definitions and try again
		cask_repo="$(brew --repository)"/Library/Taps/homebrew/homebrew-cask &&
		git -C "$cask_repo" pull --no-stat --ff-only &&
		brew install --cask --no-quarantine perforce
	} ||
	brew install homebrew/cask/perforce

	if test -n "$CC_PACKAGE"
	then
		BREW_PACKAGE=${CC_PACKAGE/-/@}
		brew install "$BREW_PACKAGE"
		brew link "$BREW_PACKAGE"
	fi
	;;
esac

case "$jobname" in
StaticAnalysis)
	sudo apt-get -q update
	sudo apt-get -q -y install coccinelle libcurl4-openssl-dev libssl-dev \
		libexpat-dev gettext make
	;;
sparse)
	sudo apt-get -q update -q
	sudo apt-get -q -y install libssl-dev libcurl4-openssl-dev \
		libexpat-dev gettext zlib1g-dev
	;;
Documentation)
	sudo apt-get -q update
	sudo apt-get -q -y install asciidoc xmlto docbook-xsl-ns make

	sudo gem install --version 1.5.8 asciidoctor
	;;
linux-gcc-default)
	sudo apt-get -q update
	sudo apt-get -q -y install $UBUNTU_COMMON_PKGS
	;;
linux32)
	linux32 --32bit i386 sh -c '
		apt update >/dev/null &&
		apt install -y build-essential libcurl4-openssl-dev \
			libssl-dev libexpat-dev gettext python >/dev/null
	'
	;;
linux-musl)
	apk add --update build-base curl-dev openssl-dev expat-dev gettext \
		pcre2-dev python3 musl-libintl perl-utils ncurses >/dev/null
	;;
pedantic)
	dnf -yq update >/dev/null &&
	dnf -yq install make gcc findutils diffutils perl python3 gettext zlib-devel expat-devel openssl-devel curl-devel pcre2-devel >/dev/null
	;;
esac

if type p4d >/dev/null && type p4 >/dev/null
then
	echo "$(tput setaf 6)Perforce Server Version$(tput sgr0)"
	p4d -V | grep Rev.
	echo "$(tput setaf 6)Perforce Client Version$(tput sgr0)"
	p4 -V | grep Rev.
fi
if type git-lfs >/dev/null
then
	echo "$(tput setaf 6)Git-LFS Version$(tput sgr0)"
	git-lfs version
fi
