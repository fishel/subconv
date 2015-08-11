#!/usr/bin/perl
use strict;
use common;

my ($fname, $start, $end, $width) = @ARGV;

open(FH, $fname) or die ("no open");
binmode(FH);

my $data = join('', <FH>);

close(FH);

my $len = length($data);

if (!$start) {
	$start = 0;
}

if (lc($start) =~ /[xabcdef]/) {
	$start = hex($start);
}

if (!$end) {
	$end = $len;
}

if (lc($end) =~ /[xabcdef]/) {
	$end = hex($end);
}

if (!$width) {
	$width = 75;
}

my $hexstr = common::tohex(substr($data, $start, $end - $start));
$hexstr =~ s/\\x/ /g;
$hexstr =~ s/^ //g;

my $chrstr = "";

for (my $pos = $start; $pos < $end; $pos++) {
	my $chr = substr($data, $pos, 1);
	
	$chrstr .= ((ord($chr) >= 0x20 and ord($chr) < 0x80)? $chr: ".");
	$chrstr .= "  ";
}

for (my $pos = 0; $pos < length($hexstr); $pos += $width) {
	print substr($hexstr, $pos, $width);
	print "\n";
	print substr($chrstr, $pos, $width);
	print "\n\n";
}
