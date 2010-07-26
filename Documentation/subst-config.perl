#!/usr/bin/perl
use 5.006002;
use strict;
use warnings;
use Getopt::Long;

Getopt::Long::Configure qw/ pass_through /;

my $rc = GetOptions(
	"varlist=s" => \my $varlist,
	"input=s"	=> \my $input,
	"output=s"	=> \my $output,
);

if (!$rc or (!-r $varlist or !-r $input)) {
	print "$0 --varlist=<varlist> --input=<in> --output=<out>\n";
	exit 1;
}

my $vars = read_varlist($varlist);
substitute_variables($vars, $input, $output);
exit 0;

sub read_varlist {
	my ($file) = @_;

	open my $fh, "<", $file or die "Can't open $file: $!";
	my %vars;

	my ($v, $last_v);
	my $in_block = 0;
	while (<$fh>) {
		if (/^(\S+)::/) {
			$v = lc $1;
			$in_block = 0;
			push @{$vars{$v}}, $_;
		} elsif (/^$/ && !$in_block) {
			if (defined $last_v && !$#{$vars{$last_v}}) {
				$vars{$last_v} = $vars{$v};
			}
			$last_v = $v;
		} elsif (defined $v) {
			push @{$vars{$v}}, $_;
			$in_block = !$in_block if /^--$/;
		}
	}

	close $fh or die "Closing $file failed: $!";

	return \%vars
}

sub substitute_variables {
	my ($varlist, $in, $out) = @_;

	open my $infh, "<", $in or die "Can't open $in: $!";
	open my $outfh, ">", $out or die "Can't open $out: $!";

	while (<$infh>) {
		if (/^\@\@CONFIG\((\S+)\)\@\@$/) {
			my $v = lc $1;
			die "Key $v not documented" unless exists $varlist->{$v};
			print $outfh @{$varlist->{$v}};
			print $outfh "\n";
		} else {
			print $outfh $_;
		}
	}

	close $infh or die "Closing $in failed: $!";
	close $outfh or die "Closing $out failed: $!";

	return;
}
