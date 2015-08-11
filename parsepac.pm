package parsepac;
use strict;
use POSIX;
use utf8;
use Unicode::Normalize;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;
use fmt;

#####
#
#####
sub readHead {
	my ($fh) = @_;
	my $buf = common::readNbytes($fh, 20);
	
	if ($buf ne ("\x01" . ("\x00" x 19))) {
		die("Not .pac, header wrong");
	}
	
	return { 'headPacBytes' => $buf };
}

#####
#
#####
sub lg {
	my $fh = shift;
	print STDERR "LOG: @_ (" . tell($fh) . ")\n";
}

#####
#
#####
sub readBlock {
	my ($fh) = @_;
	
	my $code = common::readNbytes($fh, 1, 1);
	
	unless (defined($code)) {
		return undef;
	}
	
	my $result = { 'staticPrefix' => $code };
	
	if ($code eq "\xb2") {
		$result->{'skip'} = 1;
		
		my $buf;
		read($fh, $buf, 1e10);
		
		$result->{'finalPrint'} = $code . $buf;
		
		return $result;
	}
	
	unless ($code eq "\x00" or $code eq "\xff") {
		die(sprintf("Code \\x%02x unknown, probably not .pac (pos %d)", ord($code), tell($fh)));
	}
	
	my ($idx, $idxBytes) = readPacIndex($fh, $result);
	$result->{'staticPrefix'} .= $idxBytes;
	
	$result->{'staticPrefix'} .= readStrangeByte($fh, $code, $result);
	
	my ($start, $bx) = readPacTime($fh);
	my ($end, $by) = readPacTime($fh);
	$result->{'staticPrefix'} .= $bx . $by;
	
	$result->{'index'} = $idx;
	$result->{'start'} = $start;
	$result->{'end'} = $end;
	
	my $textStatus = readPacText($fh, $code, $result);
	
	if (!$textStatus or !defined($start) or !defined($end)) {
		$result->{'skip'} = 1;
	}
	
	return $result;
}

#####
#
#####
sub readStrangeByte {
	my ($fh, $code) = @_;
	
	my $strangeByte = common::readNbytes($fh, 1);
	
	my $permittedList = "\x60-\x6f";
	
	if ($code eq "\xff") {
		$permittedList .= "\x00";
	}
	
	unless ($strangeByte =~ /^[$permittedList]$/) {
		die(sprintf("Strange byte mismatch (\\x%02x), not a .pac", ord($strangeByte)));
	}
	
	return $strangeByte;
}

#####
#
#####
sub dieWithBlockLog {
	my ($textBlock, $msg) = @_;
	
	my $dieMsg = "Failed with block `" . common::tohex($textBlock) . "': " . $msg;
	
	die($dieMsg);
}

#####
#
#####
sub readPacText {
	my ($fh, $blockCode, $struc) = @_;
	
	my ($size, $bytesToIgnore) = readRevWord($fh);
	
	my $textBlock = common::readNbytes($fh, $size);
	
	my @rawLines = split(/\xfe/, $textBlock);
	
	$struc->{'techline'} = @rawLines[0];
	
	if (@rawLines < 2 or $blockCode eq "\xff") {
		return undef;
	}
	
	$struc->{'textlines'} = [];
	
	for my $line (@rawLines[1..$#rawLines]) {
		my ($convText, $pref) = decodePac($line);
		
		push @{$struc->{'textlines'}},
			{ 'text' => $convText, 'pref' => $pref };
	}
	
	fmt::sortOutTags($struc, ['i', "<", ">"]);
	
	return 1;
}

#####
#
#####
sub decodePac {
	my ($str) = @_;
	
	my $pref = $str; 
	
	$pref =~ s/^([\x00-\x1f\xff]+).*/\1/g;
	
	$str =~ s/^\xff+//g;
	
	$str =~ s/([\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7])(.)/\2\1/g;
	
	$str =~ y/\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7/\x{303}\x{30a}\x{301}\x{300}\x{302}\x{308}\x{327}\x{30c}/;
	
	$str = NFC($str);
	
	$str =~ y/\x19\x1c\x1d\xfb\x81\x7c\x5c\x89\x8c\xba\x9a\x7d\x5d\x87\x88\xa6\xa7\xae\xa8\xad_/'""\xa0ßæÆðĐœŒøØþÞªºđ¿¡-/;
	
	$str =~ s/[\x00-\x1f]//g;
	
	return (NFC($str), $pref);
}

#####
#
#####
sub readPacTime {
	my $fh = shift;
	
	my ($rawMins, $bytes1) = readRevWord($fh);
	my ($centiSecs, $bytes2) = readRevWord($fh);
	
	my $bytes = $bytes1 . $bytes2;
	
	if ($rawMins == 65535 and $centiSecs == 65535) {
		return (undef, $bytes);
	}
	
	return ({
		'f' => $centiSecs % 100,
		'ms' => (($centiSecs % 100) * 40) % 1000,
		's' => POSIX::floor($centiSecs / 100),
		'm' => $rawMins % 100,
		'h' => POSIX::floor($rawMins / 100)
	}, $bytes);
}

#####
#
#####
sub readPacIndex {
	my ($fh) = @_;
	
	return readRevWord($fh);
}

#####
#
#####
sub readRevWord {
	my $fh = shift;
	
	my $buf = common::readNbytes($fh, 2);
	
	return (ord(substr($buf, 0, 1)) + (ord(substr($buf, 1, 1)) << 8), $buf);
}

1;
