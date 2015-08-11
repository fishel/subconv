#!/usr/bin/perl
use strict;
use POSIX;
use utf8;
use Unicode::Normalize;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;

common::parse(\&readHead, \&readBlock);

#####
#
#####
sub readHead {
	my ($fh) = @_;
	
	readTillMarker($fh, "\xfb\xef\xbd");
}

#####
#
#####
sub readBlock {
	my ($fh, $aux) = @_;
	
	if (!common::readNbytes($fh, 36, 1)) {
		return undef;
	}
	
	my $start = readTime($fh);
	
	common::readNbytes($fh, 22);
	
	my $end = readTime($fh);
	
	my $test1 = common::readNbytes($fh, 23);
	
	if (substr($test1, 18, 5) ne "FULL(") {
		die("Not .o32 (test 1)");
	}
	
	readTillMarker($fh, "\x00\x00\x0a");
	
	my $text = readTillMarker($fh, "JWC");
	
	readTillMarker($fh, "\xfb\xef\xbd");
	
	return {
		'index' => undef,
		'start' => $start,
		'end' => $end,
		'text' => convertText($text),
	};
		
	#else {
	#	my $msg = "Failed to parse `" . common::tohex($str) . "'";
	#	die($msg);
	#}
}

#####
#
#####
sub convertText {
	my ($text) = @_;
	
	my $result = "";
	
	for (my $pos = 0; $pos < length($text); $pos += 3) {
		my $ccode = substr($text, $pos + 2, 1);
		my $chr = substr($text, $pos, 2);
		
		if ($ccode =~ /[\x0a\x04J]/) {
			$result .= $chr;
		}
		
		if ($ccode eq "\x04") {
			$result .= "\x00<\x00b\x00r\x00>";
			
			$pos += 2;
		}
		elsif ($ccode eq "J") {
			return common::encDecode($result, 'UTF-16BE');
		}
		elsif ($ccode ne "\x0a") {
			die("Not .o32, `" . common::tohex("$chr$ccode") . "' (test 2)");
		}
	}
	
	die("Not .o32 (test 3)");
}

#####
#
#####
sub readTime {
	my ($fh) = @_;
	
	my @data;
	
	for (0..3) {
		push @data, readTimeByte($fh);
	}
	
	return {
		'f' => $data[0],
		's' => $data[1],
		'm' => $data[2],
		'h' => $data[3]
	};
}

#####
#
#####
sub readTimeByte {
	my ($fh) = @_;
	
	my $raw = common::readNbytes($fh, 1);
	my $ord = ord($raw);
	
	return 10 * ($ord >> 4) + ($ord % 16);
}

#####
#
#####
sub readTillMarker {
	my ($fh, $marker) = @_;
	
	my $markerLen = length($marker);
	
	my $str = common::readNbytes($fh, $markerLen, 1);
	
	if (!$str) {
		return undef;
	}
	
	my $buf = $str;
	my $len = $markerLen;
	
	while (defined($buf) and substr($str, $len - $markerLen) ne $marker) {
		$buf = common::readNbytes($fh, 1, 1);
		$str .= $buf;
		$len++;
	}
	
	return $str;
}

