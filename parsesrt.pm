package parsesrt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;
use fmt;

our $TIMESTAMP_RE = "([0-9]{2}):([0-9]{2}):([0-9]{2}),([0-9]{2,3})";

#####
#
#####
sub readHead {
	my ($fh) = @_;
	
	my @lines = <$fh>;
	
	close($fh);
	
	my $text = join("", @lines);
	my ($decText, $enc) = common::guessDecode($text);
	
	my @decLines = split(/\n/, $decText);
	my @resLines;
	
	push @resLines, $decLines[0];
	
	for my $i (1..($#decLines-1)) {
		unless (isEmpty($decLines[$i]) and isTimestamp($decLines[$i-1]) and !isIndex($decLines[$i+1])) {
			push @resLines, $decLines[$i];
		}
	}
	
	push @resLines, $decLines[$#decLines];
	
	return { 'lines' => \@resLines };
}

#####
#
#####
sub readBlock {
	my ($fh, $aux) = @_;
	my $arr = $aux->{'lines'};
	
	my $idx = readIdx($arr);
	if (!$idx) {
		return undef;
	}
	
	my ($start, $end) = readTimeStamp($arr);
	
	my $result = {
		'index' => $idx,
		'start' => $start,
		'end' => $end,
		'textlines' => []
		};
	
	while (my $line = readLine($arr)) {
		push @{$result->{'textlines'}}, { 'text' => $line };
	}
	
	fmt::sortOutTags($result, ['i', '<i>', '</i>'],
		                  ['u', '<u>', '</u>'],
		                  ['b', '<b>', '</b>']);
		
	for my $lineEntry (@{$result->{'textlines'}}) {
		$lineEntry->{'text'} =~ s/\{\\[^ ]+\}//g;
		
		$lineEntry->{'text'} =~ s/[<>]//g;
	}
	
	return $result;
}

#####
#
#####
sub isEmpty {
	my ($txt) = @_;
	
	return ($txt =~ /^\s*$/);
}

#####
#
#####
sub isTimestamp {
	my ($txt) = @_;
	
	return ($txt =~ /^$TIMESTAMP_RE --> $TIMESTAMP_RE$/);
}

#####
#
#####
sub isIndex {
	my ($txt) = @_;
	
	return ($txt =~ /^[0-9]$/);
}

#####
#
#####
sub readLine {
	my ($arr) = @_;
	
	my $line = shift @$arr;
	$line =~ s/[\n\r]//g;
	
	return (!defined($line) or $line =~ s/^\s*$//g)? undef: $line;
}

#####
#
#####
sub readTimeStamp {
	my ($arr) = @_;
	
	my $time = shift @$arr;
	$time =~ s/[\n\r]//g;
	
	my @times = split(/ --> /, $time);
	
	my $start = parseSrtTime($times[0]);
	my $end = parseSrtTime($times[1]);
	
	return ($start, $end);
}

#####
#
#####
sub parseSrtTime {
	my ($rawTime) = @_;
	
	if ($rawTime =~ /^$TIMESTAMP_RE$/) {
		my ($h, $m, $s, $ms) = ($1 + 0, $2 + 0, $3 + 0, $4 + 0);
		
		return {
			'h' => $h,
			'm' => $m,
			's' => $s,
			'ms' => $ms,
			'f' => int($ms / 40)
		};
	}
	else {
		die("`$rawTime' Time parse fail, not .srt");
	}
}

#####
#
#####
sub readIdx {
	my ($arr) = @_;
	
	my $idx = shift @$arr;
	$idx =~ s/[\n\r]//g;
	
	while (defined($idx) and $idx =~ /^\s*$/) {
		$idx = shift @$arr;
		$idx =~ s/[\n\r]//g;
	}
	
	if (!defined($idx)) {
		return undef;
	}
	
	if ($idx =~ /^[0-9]+$/) {
		return 0 + $idx;
	}
	else {
		die("Idx parse fail, not .srt");
	}
}

1;
