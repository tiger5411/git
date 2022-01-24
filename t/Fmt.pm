package Git::TAP::Formatter::Session;
use v5.18.2;
use strict;
use warnings;
use base 'TAP::Formatter::Console::ParallelSession';

our %STATE;
## TODO: This state machine needs to go past the "ok" line and grab
## the comments emitted by e.g. "say_color_tap_comment_lines" in
## test_ok_()
sub result {
	my $self = shift;
	my $result = shift;

	my $res = $self->SUPER::result($result);
	my $test_name = $self->name;

	# An AoO of test numbers and their output lines
	$STATE{$test_name} ||= [[]];

	push @{$STATE{$test_name}->[-1]} => $result;

	# When we see a new test add a new AoA for its output. We do
	# end up with the "plan" type as part of the last test, and
	# might want to split it up
	if ($result->type eq 'test') {
		push @{$STATE{$test_name}} => [];
	}

	return $res;
}

package Fmt;
use strict;
use warnings;
use base 'TAP::Formatter::Console';

sub open_test {
	my $self = shift;

	my $session = $self->SUPER::open_test(@_);
	use Data::Dumper;
	#warn "session is = " . Dumper $session;
	return bless $session => 'Git::TAP::Formatter::Session';
}

sub summary {
	my $self = shift;
	$self->SUPER::summary(@_);
	use Data::Dumper;
	die Dumper [\%STATE, \@_];
}

1;
