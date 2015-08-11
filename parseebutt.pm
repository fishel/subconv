package parseebutt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use POSIX;
use common;
use utf8;

#####
#
#####
sub readHead {
	my ($fh) = @_;
	
	my @lines = <$fh>;
	
	my $text = join("", @lines);
	my ($decText, $enc) = common::guessDecode($text);
	
	$decText =~ s/[\n\r]+/ /g;
	my $testText = lc($decText);
	
	if ($testText !~ /<tt.*<head.*<\/head>.*<body.*<div.*<p.*<\/p>.*<\/div>.*<\/body>.*<\/tt>/) {
		die("Not an EBU TT .xml");
	}
	
	return { 'text' => $decText, 'id' => 1};
}

#####
#
#####
sub readBlock {
	my ($fh, $aux) = @_;
	
	if ($aux->{'text'} !~ /^.*?(<[Pp].*?\/[Pp]>)(.*)$/) {
		return undef;
	}
	
	my $par = $1;
	$aux->{'text'} = $2;
	
	return parseTtPar($par, $aux->{'id'}++);
}

#####
#
#####
sub parseTtPar {
	my ($txt, $id) = @_;
	
	if ($txt !~ /^<[Pp]([^>]*)>(.*)<\/[Pp]>$/) {
		die("Failed to parse a paragraph");
	}
	
	my ($rawArgs, $rawText) = ($1, $2);
	my ($start, $end) = parseTtTimestamps($rawArgs);
	my $text = cleanTtText($rawText);
	
	return {
		'index' => $id,
		'start' => $start,
		'end' => $end,
		'textlines' => $text
	};
}

#####
#
#####
sub cleanTtText {
	my ($raw) = @_;
	
	$raw =~ s/<\/?span[^>]*>/ /g;
	
	my @lines = ();
	
	for my $line (split(/<\s*br\s*\/\s*>/, $raw)) {
		$line =~ s/^\s+//g;
		push @lines, { 'text' => $line };
	}
	
	return \@lines;
}

#####
#
#####
sub parseTtTimestamps {
	my ($rawStr) = @_;
	
	my $parsed = xmlTagFields($rawStr);
	
	my ($start, $end);
	
	if ($parsed->{'begin'}) {
		$start = parseTtTime($parsed->{'begin'});
	}
	else {
		die("No begin ($rawStr)");
	}
	
	if ($parsed->{'end'}) {
		$end = parseTtTime($parsed->{'end'});
	}
	else {
		die("No end ($rawStr)");
	}
	
	return ($start, $end);
}

#####
#
#####
sub parseTtTime {
	my ($str) = @_;
	
	if ($str =~ /^([0-9]{2}):([0-9]{2}):([0-9]{2}).([0-9]{2,3})$/) {
		my ($h, $m, $s, $rawForC) = ($1, $2, $3, $4);
		
		my $fOrC = (length($rawForC) == 2)? ($rawForC + 0) / 40: ($rawForC + 0);
		
		return {
			'h' => $h,
			'm' => $m,
			's' => $s,
			'f' => $fOrC,
			'ms' => $fOrC * 40
		};
	}
	elsif ($str =~ /^([0-9]+(:?\.[0-9]+)?)s$/) {
		return scalarToStruc($1 + 0);
	}
	else {
		die ("String `$str' is not a parseable timestamp");
	}
}

#####
#
#####
sub scalarToStruc {
	my ($rawSecs) = @_;
	my $millis = POSIX::fmod($rawSecs, 1);
	
	my $secs = int($rawSecs) % 60;
	
	my $rawMinutes = POSIX::floor($rawSecs / 60);
	my $minutes = $rawMinutes % 60;
	
	my $hours = POSIX::floor($rawMinutes / 60);
	
	return {
		'h' => $hours,
		'm' => $minutes,
		's' => $secs,
		'ms' => $millis,
		'f' => $millis / 40
	};
}

#####
#
#####
sub xmlTagFields {
	my $str = shift;
	my $resultHash = {};
	
	while ($str =~ /^\s+([^=[:space:]]+)=['"]([^'"]+)["'](.*)\s*$/) {
		my $fieldName = $1;
		my $fieldValue = $2;
		$str = $3;
		
		#in case the field value includes a \"
		while ($fieldValue =~ /\\$/) {
			if ($str =~ /([^"]*)"(.*)\s*$/) {
				$fieldValue .= "\"" . $1;
				$str = $2;
			}
			else {
				die("Failed to parse a field value with a double quote inside: `$str'");
			}
		}
		
		$resultHash->{$fieldName} = $fieldValue;
	}
	
	if ($str !~ /^\s*$/) {
		die ("String left-overs from parsing xml tag fields: `$str'");
	}
	
	return $resultHash;
}

1;
