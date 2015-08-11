package parse890;
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
	my $head = common::readNbytes($fh, 0x180);
	
	for my $i (0, 1, 142, 143, 144) {
		if (substr($head, $i, 1) ne "\x00") {
			die("Header byte check failed, not .890");
		}
	}
	
	return { 'filler-ended-count' => 0, 'total-count' => 0, 'head' => $head };
}

#####
#
#####
sub readBlock {
	my ($fh, $aux) = @_;
	
	my ($idx, $idxBytes) = readCavenaIndex($fh);
	
	if (defined($idx)) {
		my ($start, $startBytes) = readCavenaTime($fh);
		my ($end, $endBytes) = readCavenaTime($fh);
		
		checkTiming($start, $end);
		
		my $someBytes = common::readNbytes($fh, 8);
		
		my $lineOne = readCavenaLine($fh, $aux);
		
		my $intermediateBytes = common::readNbytes($fh, 6);
		
		my $lineTwo = readCavenaLine($fh, $aux);
		
		my $result = {
			'index' => $idx,
			'start' => $start,
			'end' => $end,
			'preBytes' => $idxBytes . $startBytes . $endBytes . $someBytes,
			'interBytes' => $intermediateBytes,
			'textlines' => [ { 'text' => $lineOne }, { 'text' => $lineTwo } ]
		};
		
		fmt::sortOutTags($result, ['i', '<i>', '</i>']);
		
		return $result;
	}
	else {
		my $fillerEndedRatio = 1.0 * $aux->{'filler-ended-count'} / $aux->{'total-count'};
		
		if ($aux->{'total-count'} > 2 and $fillerEndedRatio < 0.5) {
			die("Not enough filler-ended lines ($fillerEndedRatio), probably not .890");
		}
		
		return undef;
	}
}

#####
#
#####
sub readCavenaLine {
	my ($fh, $aux) = @_;
	
	my $buf = common::readNbytes($fh, 51);
	
	$aux->{'total-count'}++;
	
	if ($buf =~ /\x7f+[\x80-\xff]?$/) {
		#die("Buffer not ending with fillers, not a .890: " . common::tohex($buf));
		$aux->{'filler-ended-count'}++;
	}
	
	$buf =~ s/[\x7f]//g; # filler removed
	
	$buf =~ s/^\x88([^\x88\x98]+)\x98?$/<i>\1<\/i>/g;
	
	while ($buf =~ /^(.*)\x88([^\x88\x98]+)\x98(.*)$/) {
		$buf = $1 . "<i>" . $2 . "</i>" . $3;
	}
	
	$buf =~ s/<\/i>(\s*)<i>/\1/g;
	
	$buf =~ s/[\x88\x98]//g;
	
	$buf =~ s/([\x81\x82\x83\x85\x86\x87\x89\x8a\x8c])(.)/\2\1/g;
	$buf =~ y/\x81\x82\x83\x85\x86\x87\x89\x8a\x8c/\x{300}\x{301}\x{302}\x{303}\x{308}\x{327}\x{30c}\x{308}\x{30a}/;
	
	$buf =~ y/\x07\x17\x1f\x1c\x1e\x1b\x0e\x01\x11\]\x1d/ŒœØøÆæßÇçÅå/;
	$buf =~ y/\x0b\x1a\x14\x02\x12\x03\x13/\xa0\x{201c}\xabĐðÞþ/;
	$buf =~ y/\xa8\xac\xbe\xa6\x05\x15/©°―ªº²/;
	
	return NFC($buf);
}

#####
#
#####
sub readCavenaTime {
	my $fh = shift;
	
	my $buf = common::readNbytes($fh, 3);
	
	my $frames = 0;
	
	for my $pos (0..2) {
		$frames += ord(substr($buf, $pos, 1)) << (8 * (2 - $pos));
	}
	
	my $seconds = POSIX::floor($frames / 25);
	my $minutes = POSIX::floor($seconds / 60);
	
	return ({
		'fullframes' => $frames,
		'f' => $frames % 25,
		'ms' => ($frames % 25) * 40,
		's' => $seconds % 60,
		'm' => $minutes % 60,
		'h' => POSIX::floor($minutes / 60)
	}, $buf);
}

#####
#
#####
sub checkTiming {
	my ($start, $end) = @_;
	
	my $startFrames = $start->{'fullframes'};
	my $endFrames = $end->{'fullframes'};
	
	if ($endFrames <= $startFrames or (($endFrames - $startFrames) > 25*60*5)) {
		die("TIming indicates this is not a .890");
	}
}

#####
#
#####
sub readCavenaIndex {
	my ($fh) = shift;
	
	my $buf = common::readNbytes($fh, 4, 1);
	
	if (!defined($buf)) {
		return undef;
	}
	
	my $buf2 = common::readNbytes($fh, 2);
	
	my $bytes = $buf . $buf2;
	
	if ($buf2 eq "\x00\x01") {
		return (1, $bytes);
	}
	else {
		my $result = (ord(substr($buf2, 1, 1)) >> 4) % 16;
		$result += ord(substr($buf2, 0, 1)) << 4;
		
		return ($result, $bytes);
	}
}

1;
