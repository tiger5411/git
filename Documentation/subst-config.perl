#!/usr/bin/perl -w

use strict;

my $varlist = shift @ARGV;
my $fh;
open $fh, "<", $varlist or die "cannot open $varlist: $!";
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

close $fh or die "eh? close failed: $!";

my $input = shift @ARGV;
my $output = shift @ARGV;
my ($infh, $outfh);
open $infh, "<", $input;
open $outfh, ">", $output;

while (<$infh>) {
	if (/^\@\@CONFIG\((\S+)\)\@\@$/) {
		my $v = lc $1;
		die "Key $v not documented" unless defined $vars{$v};
		print $outfh @{$vars{$v}};
		print $outfh "\n";
	} else {
		print $outfh $_;
	}
}

close $infh or die "closing input failed: $!";
close $outfh or die "closing output failed: $!";
