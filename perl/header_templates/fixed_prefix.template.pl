BEGIN {
    chomp(my $perlPath = `git config --get core.perlPath`);;
    if ($perlPath and $^X ne $perlPath) {
	exec($perlPath, $0, @ARGV);
    }
}
use lib (split(/@@PATHSEP@@/, $ENV{GITPERLLIB} || '@@INSTLIBDIR@@'));
