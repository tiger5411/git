#!/usr/bin/perl
use strict;
use warnings;

while (<STDIN>) {
    s/\bgettext "([^"]+)"?$/printf "%s" "$1"/;
    s/\bgettext "([^"]+)" >&2?$/printf "%s" "$1" >&2/;

    s/"\$\(gettext "([^"]+)"\)"/"$1"/;
    s/\bgettextln "([^"]+)"?$/echo "$1"/;
    s/\bgettextln "([^"]+)" >&2?$/echo "$1" >&2/;

    s/"\$\(eval_gettext "([^"]+)"\)/'"' . remove_backslash_dollah($1) . '"'/ge;

    print;
}

sub remove_backslash_dollah {
    my $text = shift;
    $text =~ s/\\\$/\$/g;
    $text;
}
