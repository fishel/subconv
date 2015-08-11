package parseebustl;
use strict;
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
sub readGsi {
	my ($fh) = @_;
	
	my $gsi = readRawGsi($fh);
	
	my $rawEnc = 0 + $gsi->{'CCT'};
	
	my @encArr = (qw(iso-6937-2:1983));
	
	return { 'enc' => $encArr[$rawEnc], 'idx' => 0, %$gsi };
}

#####
#
#####
sub readBytes {
	my ($fh, $key, $nrBytes, $check, $dontDie) = @_;
	
	my $data = common::readNbytes($fh, $nrBytes, $dontDie);
	
	if ($check and $data !~ /^$check$/) {
		die("Not an .stl file (bytes `$key' = " . common::tohex($data) . " failed check)");
	}
	
	return $data;
}

#####
#
#####
sub readRawGsi {
	my ($fh) = @_;
	
	my $gsi = {};
	
	for my $tuple (["CPN", 3, "[48][356][0357]"],
		["DFC", 8, "STL[23][50].01"],
		["DSC", 1, "[ 012]"],
		["CCT", 2, "0[01234]"],
		["LC", 2],
		["OPT", 32],
		["OET", 32],
		["TPT", 32],
		["TET", 32],
		["TN",  32],
		["TCD", 32],
		["SLR", 16],
		["CD", 6, "[0-9]{6}"],
		["RD", 6, "[0-9]{6}"],
		["RN", 2, "[0-9]{2}"],
		["TNB", 5, "[0-9]{5}"],
		["TNS", 5, "[0-9]{5}"],
		["TNG", 3, "[0-9]{3}"],
		["MNC", 2, "[0-9]{2}"],
		["MNR", 2, "[0-9]{2}"],
		["TCS", 1, "[01]"],
		["TCP", 8, "[0-9]{8}"],
		["TCF", 8, "[0-9]{8}"],
		["TND", 1, "[0-9]"],
		["DSN", 1, "[0-9]"],
		["CO", 3, "[A-Z]{3}"],
		["PUB", 32],
		["EN", 32],
		["ECD", 32],
		["UDA", 576],
		["EXT", 75]
		) {
		my $key = shift @$tuple;
		$gsi->{$key} = readBytes($fh, $key, @$tuple);
	}
	
	return $gsi;
}

#####
#
#####
sub readRawTti {
	my ($fh) = @_;
	
	my $tti = {};
	
	$tti->{'SGN'} = common::readNbytes($fh, 1, 1);
	
	unless (defined($tti->{'SGN'})) {
		return undef;
	}
	
	for my $tuple (["SN", 2],
		["EBN", 1],
		["CS", 1, "[\x00-\x03]"],
		["TCI", 4, "[\x00-\x17][\x00-\x3b][\x00-\x3b][\x00-\x1d]"],
		["TCO", 4, "[\x00-\x17][\x00-\x3b][\x00-\x3b][\x00-\x1d]"],
		["VP", 1, "[\x01-\x63]"],
		["JC", 1, "[\x00-\x03]"],
		["CF", 1, "[\x00\x01]"],
		["TF", 112]
		) {
		my $key = shift @$tuple;
		$tti->{$key} = readBytes($fh, $key, @$tuple);
	}
	
	return $tti;
}

#####
#
#####
sub readTti {
	my ($fh, $aux) = @_;
		
	my $tti = readRawTti($fh);
	
	while ($tti and !(ord($tti->{'EBN'}) == 0xff and ord($tti->{'CF'}) == 0x0)) {
		$tti = readRawTti($fh);
	}

	if ($tti) {
		$aux->{'idx'}++;
		
		my $startTime = parseTime($tti->{'TCI'});
		my $finTime = parseTime($tti->{'TCO'});
		
		if (!defined($startTime) or !defined($finTime)) {
			return undef;
		}
		
		return {
			%$tti,
			'index' => $aux->{'idx'},
			'start' => $startTime,
			'end' => $finTime,
			'textlines' => parseText($tti->{'TF'})
		};
	}
	else {
		return undef;
	}
}

#####
#
#####
sub parseText {
	my ($raw) = @_;
	
	$raw =~ s/\x8F//g;
	
	my @rawLines = split(/\x8A/, $raw);
	my @paramLines = map { 'text' => $_ }, @rawLines;
	
	my $result = {
		'textlines' => \@paramLines
	};
	
	fmt::sortOutTags($result, ['i', "\x80", "\x81"],
		                  ['u', "\x82", "\x83"],
		                  ['b', "\x84", "\x85"]);
	
	for my $lineEntry (@{$result->{'textlines'}}) {
		my $txt = $lineEntry->{'text'};
		
		if ($txt =~ /^([\x00-\x1f]+\x20*)(.*)$/) {
			$txt = $2;
			$lineEntry->{'stl-pref'} = $1;
		}
		
		$txt =~ s/\x80/<i>/g;
		$txt =~ s/\x81/<\/i>/g;
		$txt =~ s/\x82/<u>/g;
		$txt =~ s/\x83/<\/u>/g;
		$txt =~ s/\x84/<b>/g;
		$txt =~ s/\x85/<\/b>/g;
		
		$txt =~ s/([\xc1-\xc8\xca\xcb\xcd-\xcf])([A-Za-z])/\2\1/g;
		$txt =~ y/\xc1-\xcf/\x{300}-\x{304}\x{306}-\x{308}\xc9\x{30a}\x{327}\xcc\x{30b}\x{328}\x{30c}/;
		
		$txt =~ y/\xa0-\xaf/\xa0-\xa7\xa4\x{2018}\x{201c}\xab\x{2190}-\x{2193}/;
		$txt =~ y/\xb0-\xbf/\xb0-\xb3\xd7\xb5-\xb7\xf7\x{2019}\x{201d}\xbb-\xbf/;
		$txt =~ y/\xd0-\xd7\xdc-\xdf/\x{2015}\xb9\xae\xa9\x{2122}\x{266a}\xac\xa6\x{215b}-\x{215e}/;
		$txt =~ y/\xe0-\xef/\x{2126}\xc6\x{110}\xaa\x{126}\xe5\x{132}\x{13f}\x{141}\xd8\x{152}\xba\xde\x{166}\x{14a}\x{149}/;
		$txt =~ y/\xf0-\xff/\x{138}\xe6\x{111}\xf0\x{127}\x{131}\x{133}\x{140}\x{142}\xf8\x{153}\xdf\xfe\x{167}\x{14b}\xad/;
		$txt =~ s/[\x00-\x0f\x10-\x1f\x86-\x8f\x90-\x9f]//g;
		
		$lineEntry->{'text'} = NFC($txt);
	}
	
	return $result->{'textlines'};
}

#####
#
#####
sub parseTime {
	my ($raw) = @_;
	
	my $h = ord(substr($raw, 0, 1));
	my $m = ord(substr($raw, 1, 1));
	my $s = ord(substr($raw, 2, 1));
	my $f = ord(substr($raw, 3, 1));
	
	if ($h == 0 and $m == 255 and $s == 0 and $f == 0) {
		return undef;
	}
	
	return {
		'f' => $f,
		'ms' => $f * 40,
		's' => $s,
		'm' => $m,
		'h' => $h
	};
}

1;
