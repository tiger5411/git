package Git::TAP::Formatter::Session;
use v5.18.2;
use strict;
use warnings;
use base 'TAP::Formatter::Console::ParallelSession';

our %TEST;

sub result {
	my $self = shift;
	my $result = shift;

	my $res = $self->SUPER::result($result);

	my $test_name = $self->name;
	use Data::Dumper;

	my $formatter = $self->formatter;
	my $state = ($formatter->{_git_state} ||= {});
	$state->{$test_name}->{n} ||= 0;
	my $n = $state->{$test_name}->{n};
	if ($result->type eq 'test') {
		$state->{$test_name}->{n} = $result->{test_num};
	}

	push @{$state->{$test_name}->{_out}->[$n]} => $result->raw;

	warn Dumper [$self, $res, $result];

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
	die Dumper \@_;
}

1;
