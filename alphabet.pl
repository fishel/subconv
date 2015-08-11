#!/usr/bin/perl
use strict;

my %h;

#binmode(STDIN, ":utf8");
#binmode(STDOUT, ":utf8");

while (<STDIN>) {
	while (my $x = chop) {
		$h{$x}++;
	}
}

for my $k (sort { $h{$b} <=> $h{$a} } keys %h) {
	my $ord = ord($k);
	printf "\\x%02x - `%s' - %d\n", $ord, (($ord >= 0x20 and $ord <= 0x7f)? $k: 'aux'), $h{$k};
}
