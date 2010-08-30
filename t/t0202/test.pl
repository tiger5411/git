#!/usr/bin/perl
use 5.006002;
use lib (split(/:/, $ENV{GITPERLLIB}));
use warnings;
use strict;
use Test::More tests => 11;
use Git::I18N;
use POSIX qw(:locale_h);

my $has_gettext_library = $Git::I18N::__HAS_LIBRARY;

ok(1, "Testing Git::I18N version $Git::I18N::VERSION with " .
	 ($has_gettext_library
	  ? (defined $Locale::Messages::VERSION
		 ? "Locale::Messages version $Locale::Messages::VERSION"
		 : "Locale::Messages version <1.17")
	  : "NO Perl gettext library"));
ok(1, "Git::I18N is located at $INC{'Git/I18N.pm'}");

ok($Git::I18N::VERSION, 'sanity: Git::I18N defines a $VERSION');
{
	my $exports = @Git::I18N::EXPORT;
	ok($exports, "sanity: Git::I18N has $exports export(s)");
}
is_deeply(\@Git::I18N::EXPORT, \@Git::I18N::EXPORT_OK, "sanity: Git::I18N exports everything by default");

# prototypes
{
	# Add prototypes here when modifying the public interface to add
	# more gettext wrapper functions.
	my %prototypes = (qw(
		__	$
    ));
	while (my ($sub, $proto) = each %prototypes) {
		is(prototype(\&{"Git::I18N::$sub"}), $proto, "sanity: $sub has a $proto prototype");
	}
}

# Test basic passthrough in the C locale
{
	local $ENV{LANGUAGE} = 'C';
	local $ENV{LC_ALL}   = 'C';
	local $ENV{LANG} = 'C';

	my ($got, $expect) = (('TEST: A Perl test string') x 2);

	is(__($got), $expect, "Passing a string through __() in the C locale works");
}

my %utf_to_x = (
	'UTF-8' => { qw(
		locale_env GETTEXT_LOCALE
		locale_loc is_IS_locale
	) },
	'ISO-8859-1' => { qw(
		locale_env GETTEXT_ISO_LOCALE
		locale_loc is_IS_iso_locale
	) },
);

for my $test (qw(UTF-8 ISO-8859-1)) {
  # Test a basic message on different locales
  SKIP: {
	unless ($ENV{$utf_to_x{$test}{locale_env}}) {
		# Can't reliably test __() with a non-C locales because the
		# required locales may not be installed on the system.
		#
		# We test for these anyway as part of the shell
		# tests. Skipping these here will eliminate failures on odd
		# platforms with incomplete locale data.

		skip "$utf_to_x{$test}{locale_env} must be set by lib-gettext.sh for exhaustive Git::I18N tests", 2;
	}

	# The is_IS UTF-8 locale passed from lib-gettext.sh
	my $is_IS_locale = $ENV{$utf_to_x{$test}{locale_loc}} // die "Internal error: no locale for $test";

	my $test = sub {
		my ($got, $expect, $msg, $locale) = @_;
		# Maybe this system doesn't have the locale we're trying to
		# test.
		my $locale_ok = setlocale(LC_ALL, $locale);
		is(__($got), $expect, "UTF-8 -> $test: $msg a gettext library + <$locale> locale <$got> turns into <$expect>");
	};

	my $env_C = sub {
		$ENV{LANGUAGE} = 'C';
		$ENV{LC_ALL}   = 'C';
	};

	my $env_is = sub {
		$ENV{LANGUAGE} = 'is';
		$ENV{LC_ALL}   = $is_IS_locale;
	};

	# Translation's the same as the original
	my ($got, $expect) = (('TEST: Hello World!') x 2);

	if ($has_gettext_library) {
		{
			local %ENV; $env_C->();
			$test->($got, $expect, "With", 'C');
		}

		{
			my ($got, $expect) = ($got, 'TILRAUN: Halló Heimur!');
			local %ENV; $env_is->();
			$test->($got, $expect, "With", $is_IS_locale);
		}
	} else {
		{
			local %ENV; $env_C->();
			$test->($got, $expect, "Without", 'C');
		}

		{
			local %ENV; $env_is->();
			$test->($got, $expect, "Without", 'is');
		}
	}
  }
}
