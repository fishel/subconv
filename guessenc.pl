#!/usr/bin/perl
use strict;
use Encode;
use Encode::Guess;
use Encode::Encoding;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;

my $fh;

open ($fh, $ARGV[0]) or die ("Failed to open `" . $ARGV[0] . "' for reading");
	
my @lines = <$fh>;

my $text = join("", @lines);
my ($decText, $enc) = common::guessDecode($text);

print "$enc\n";

#print encode('utf8', $decText);

close($fh);
