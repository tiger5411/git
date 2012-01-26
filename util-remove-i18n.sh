#!/usr/bin/perl
use strict;
use warnings;

while (<STDIN>) {
    s/"\$\(gettext "([^"]+)"\)"/"$1"/;
    s/\bgettextln "([^"]+)"?$/echo "$1"/;
    s/\bgettextln "([^"]+)" >&2?$/echo "$1" >&2/;

    print;
}
