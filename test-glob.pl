use strict;
use warnings;
use Test::More qw(no_plan);
use Text::Glob qw(glob_to_regex_string);

if (@ARGV) {
    print glob_to_rx(@ARGV), "\n";
    exit;
}

my $test_data = do 'test-data.pl';

for my $test (@$test_data) {
    my $ok  = $test->[0];
    my $str = $test->[1];
    my $pat = $test->[2];

    s/^['"]//, s/['"]$// for $str, $pat;

    my $pat_rx = glob_to_regex_string($pat);
    eval {
	cmp_ok(
	    ($str =~ $pat_rx ? 1 : 0),
	    '==',
	    $ok,
	    "<$ok> on the glob <$pat> translated to <$pat_rx> when matched against <$str>",
	);
	1;
    } or do {
	fail("PANIC on $str =~ $pat_rx (converted from $pat): $@");
    };
}

sub glob_to_rx {
    my $glob = shift;
    my $rx = '';
    my @glob = split //, $glob;

    $rx = '(?s)^';
    for (my $i = 0; $i < @glob; $i++) {
	my $c = $glob[$i];
	my $n = $i == $#glob ? '' : $glob[$i + 1];
	my $p = $i > 0 ? $glob[$i - 1] : '';

	#warn "$p $c $n";
	if (quotemeta($c) ne $c and $p eq '\\') {
	    $rx .= $c;
	}
	elsif (quotemeta($c) eq $c and $p eq '\\') {
	    # The glob fo\o is equivalent to fo\\o
	    $rx .= '\\';
	    $rx .= $c;
	}
	elsif ($c eq '*') {
	    if ($n eq '*') {
		$rx .= '(?:(?:[^/]*(?:\/|$))*)';
		$i++;
	    } else {
		$rx .= '[^/]*';
	    }
	}
	elsif ($c eq '?') {
	    $rx .= '[^/]';
	}
	elsif ($c eq '!' and $p eq '[') {
	    $rx .= '^';
	}
	else {
	    $rx .= $c;
	}
    }
    $rx .= '$';

    return $rx;
}

__END__


    for (my $i = 0; $i < @glob; $i++) {
	my $c = $glob[$i];


    }



	if ($prev eq '/' and quotemeta($cur) eq $cur) {
	    # A glob like f\oo is equivalent to foo
	    $rx .= $cur;
	} elsif ($prev eq '\\' and quotemeta($cur) ne $cur) {
	    $rx .= $cur;
	} elsif ($prev eq '?') {
	    $rx .= '.';
	} elsif ($prev eq '*' and $cur ne '*') {
	    $rx .= '[^/]*';
	} elsif ($prev eq '*' and $cur eq '*') {
	    $rx .= '.*';
	}  else {
	    $rx .= $prev;
	}

	if ($i == @glob - 1) {
	    if ($cur eq '?') {
		$rx .= '.';
	    } elsif ($cur eq '*') {
		$rx .= '[^/]*';
	    } else {
		$rx .= $cur;
	    }
	}
