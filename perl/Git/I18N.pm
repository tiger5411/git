package Git::I18N;
use strict;
use warnings;
use Exporter;
use base 'Exporter';

our $VERSION = '0.01';

our @EXPORT = qw(gettext);
our @EXPORT_OK = @EXPORT;

sub __bootstrap_locale_messages {
	our $TEXTDOMAIN = 'git';
	our $TEXTDOMAINDIR = $ENV{GIT_TEXTDOMAINDIR} || '++LOCALEDIR++';

	require POSIX;
	POSIX->import(qw(setlocale));
	# Non-core prerequisite module
	require Locale::Messages;
	Locale::Messages->import(qw(:locale_h :libintl_h));

	setlocale(LC_MESSAGES(), '');
	setlocale(LC_CTYPE(), '');
	textdomain($TEXTDOMAIN);
	bindtextdomain($TEXTDOMAIN => $TEXTDOMAINDIR);

	return;
}

BEGIN
{
	local ($@, $!);
	eval { __bootstrap_locale_messages() };
	if ($@) {
		# Oh noes, no Locale::Messages here
		*gettext = sub ($) { $_[0] };
	}
}

1;

__END__

=head1 NAME

Git::I18N - Perl interface to Git's Gettext localizations

=head1 SYNOPSIS

	use Git::I18N;

	print gettext("Welcome to Git!\n");

	printf gettext("The following error occured: %s\n"), $error;

=head1 DESCRIPTION

Git's internal interface to Gettext via L<Locale::Messages>. If
L<Locale::Messages> can't be loaded (it's not a core module) we
provide stub passthrough fallbacks.

=head1 FUNCTIONS

=head2 gettext($)

L<Locale::Messages>'s gettext function if all goes well, otherwise our
passthrough fallback function.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avarab@gmail.com>

=cut
