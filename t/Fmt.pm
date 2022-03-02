package Git::TAP::Formatter::Session;
use v5.18.2;
use strict;
use warnings;
use base 'TAP::Formatter::Console::ParallelSession';

our %STATE;
sub result {
	my $self = shift;
	my $result = shift;

	my $res = $self->SUPER::result($result);
	my $test_name = $self->name;

	# An AoO of test numbers and their output lines
	$STATE{$test_name} ||= [{lines => []}];

	push @{$STATE{$test_name}->[-1]->{lines}} => $result;

	# When we see a new test add a new AoA for its output. We do
	# end up with the "plan" type as part of the last test, and
	# might want to split it up
	if ($result->type eq 'test') {
		push @{$STATE{$test_name}} => {};
	}

	return $res;
}

package Fmt;
use strict;
use warnings;
use List::MoreUtils qw(firstidx);
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

	## This state machine needs to go past the "ok" line and grab
	## the comments emitted by e.g. "say_color_tap_comment_lines" in
	## test_ok_()
	for my $test (sort keys %STATE) {
		for (my $i = 1; $i <= $#{$STATE{$test}}; $i++) {
			my @lines = @{$STATE{$test}->[$i]->{lines}};
			my $break = firstidx { $_->raw eq '' } @lines;
			my @source = splice @lines, 0, $break;

			splice @lines, 0, 1; # Splice out the '' item
			push @{$STATE{$test}->[$i - 1]->{lines}} => @source;

			$STATE{$test}->[$i]->{lines} = \@lines;

			# Since we parsed out the source already,
			# let's make it easily machine-readable, and
			# parse the rest.
			$STATE{$test}->[$i]->{source} = \@source;
			my @trace = map { $_->{is_trace} = 1 } grep { $_->raw =~ /^\+ / } @lines;
			$STATE{$test}->[$i]->{trace} = \@trace if @trace;
		}
	}

	my $aggregator = $_[0];
	for my $failed ($aggregator->failed) {
		my ($parser) = $aggregator->parsers($failed);
		for my $i ($parser->failed) {
			my $idx = $i - 1;
			my @lines = @{$STATE{$failed}->[$idx]->{lines}};
			my ($test) = grep { $_->is_test } @lines;

			say "Failed in $failed#$i:";
			say join "\n", map {
				s/^/ ==> /gr;
			} map {
				sprintf("%-6s => %s",
				     $_->{is_trace} ? "trace" :
				     $_->is_unknown ? "output" :
				     $_->is_comment ? "source" :
				     $_->type,
				     $_->raw,
			     );
			} sort {
				# the "is_trace" may be undef
				no warnings qw(uninitialized);
				# The "[not ]ok" line first...
				$b->is_test <=> $a->is_test ||
				# Then "comment" (i.e. test source)
				$b->is_comment <=> $a->is_comment ||
				# Then the "+ " trace of execution
				$b->{is_trace} <=> $a->{is_trace}
			} @lines;
		}
	}
}

1;
