#!/usr/bin/perl
use v5.28.0;
BEGIN { say $^X }
BEGIN {
    chomp(my $perlPath = "git config --get core.perlPath");
    exec $perlPath, @ARGV if $perlPath and $^X ne $perlPath;
}
use v5.29.0;
BEGIN { say $^X }
