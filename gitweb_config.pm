#
# This program is licensed under the GPLv2
#

#
# Configuration Options for gitweb
#
# gitbin: Location of the git-core binaries
#	"/usr/bin"
#
# git_temp: Location for temporary files needed for diffs
#	"/tmp/gtiweb"
#
# projectroot: Absolute fs-path which will be prepended to the project path
#	"/pub/scm"
#	"/home/kay/public_html/pub/scm"
#
# projects_list: Source of projects list
#	"/pub/scm"
#	"index/index.aux"
#
# home_text: Html text to include at home page
#	"indextext.html"
#
# description_len: Length of description field
#	25
#	35

package gitweb_config;

my $opts = {
    gitbin => "/usr/bin",
    git_temp => "/tmp/gitweb",
    projectroot => "/pub/software",
    projects_list => "/pub/software",
    home_text => "indextext.html",
    description_len => 35,
};

sub get_config_opts { return $opts; }

1;
