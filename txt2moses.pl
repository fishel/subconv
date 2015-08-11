#!/usr/bin/perl
use strict;

my @toprint = ();
my $idx;

while (<STDIN>) {
	s/[\n\r]//g;
	
	if (/^([0-9]+)(\s+[0-9]{2}(:[0-9]{2}){3}){2}$/) {
		$idx = $1;
	}
	elsif (/^\s*$/) {
		my $output = join(" ", @toprint) . "\n";
		print $output;
		#print STDERR "$idx\t$output";
		@toprint = ();
	}
	else {
		push @toprint, $_;
	}
}
