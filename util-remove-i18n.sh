#!/usr/bin/perl
use strict;
use warnings;

while (<STDIN>) {
    s/"\$\(gettext "([^"]+)"\)"/"\1"/;

    print;
}
