package Git::Private::Command;
use strict;
use warnings;

sub new {
	my ($class, %opt) = @_;
	my $self = bless \%opt => $class;
	return $self;
}

sub open {
	my $self = shift;

	my ($command, $mode, $args) = @$self{qw(command mode args)};
	my @cmd = ($command, @$args);
	open $self->{fh}, $mode, @cmd or die "could not open($mode, $command, @$args): $!";
	return $self;
}

sub close {
	my $self = shift;

	my ($command, $mode, $args) = @$self{qw(command mode args)};

	return $self if close $self->{fh};
	die "could not close($command, @$args): $!" if $!;
	my $raw_code = $self->{raw_code} = $?;
	my $code     = $self->{code} = $? >> 8;
	if (my @codes_ok = @{$self->{code_ok} || []}) {
		return $self if grep { $code == $_ } @codes_ok;
		die "got unexpected exit code $code (raw: $raw_code) from $command @$args"
	}
	return $self;
}

sub get {
	my $self = shift;

	my ($fh, $devnull, $slurp) = @$self{qw(fh devnull slurp)};
	if ($devnull) {
		# Consume the output before the close(). Emulates
		# piping to /dev/null.
		1 while <$fh>;
	} elsif ($slurp) {
		local $/;
		chomp(@{$self->{out}} = <$fh>);
	} else {
		chomp(@{$self->{out}} = <$fh>);
	}
	return $self;
}

sub run {
	my $self = shift;
	$self->open->get->close;
	return $self;
}

sub out {
	my $self = shift;
	my ($out, $devnull, $slurp) = @$self{qw(out devnull slurp)};
	if ($devnull) {
		return;
	} elsif ($slurp) {
		return $out->[0];
	} else {
		return @$out;
	}
}

1;
