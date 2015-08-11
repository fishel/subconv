package showebustl;
use strict;
use Unicode::Normalize;
use POSIX qw(strftime);
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;
use showpac;
use fmt;

#####
#
#####
sub printStlBytes {
	my ($struc, $key, $default, $force) = @_;
	
	my $data = $struc->{$key};
	
	return ((defined($data) and !$force)? $data: $default);
}

#####
#
#####
sub displayGsi {
	my ($headInfo, $size) = @_;
	
	my $date = strftime "%y%m%d", localtime;
	my $fmtSize = sprintf("%05d", $size);
	
	my $result = "";
	
	for my $pair (["CPN", "850"],
			["DFC", "STL25.01"],
			["DSC", "0"],
			["CCT", "00"],
			["LC", "09"],
			["OPT", "Program Title                   "],
			["OET", "Episode Title                   "],
			["TPT", "Program Title Translation       "],
			["TET", "Episode Title Translation       "],
			["TN",  "SUMAT Moses Engine              "],
			["TCD", "Somewhere on a server           "],
			["SLR", "Huh?            "],
			["CD", $date],
			["RD", $date, 1],
			["RN", "00"],
			["TNB", $fmtSize],
			["TNS", $fmtSize],
			["TNG", "001"],
			["MNC", "58"],
			["MNR", "11"],
			["TCS", "1"],
			["TCP", "00000000"],
			["TCF", "00000000"],
			["TND", "1"],
			["DSN", "1"],
			["CO", "PRK"],
			["PUB", " " x 32],
			["EN", " " x 32],
			["ECD", " " x 32],
			["UDA", " " x 576],
			["EXT", " " x 75]
			) {
		$result .= printStlBytes($headInfo, @$pair);
	}
	
	return $result;
}

#####
#
#####
sub encodeTime {
	my ($timeStruc) = @_;
	
	return chr($timeStruc->{'h'}) . chr($timeStruc->{'m'}) . chr($timeStruc->{'s'}) . chr($timeStruc->{'f'});
}

#####
#
#####
sub fmtText {
	my ($text, $fmt) = @_;
	
	if ($fmt eq "i") {
		return "\x80" . $text . "\x81";
	}
	elsif ($fmt eq "u") {
		return "\x82" . $text . "\x83";
	}
	elsif ($fmt eq "b") {
		return "\x84" . $text . "\x85";
	}
	else {
		return $text;
	}
}

#####
#
#####
sub encodeText {
	my ($block) = @_;
	
	my $finalText = join("\x8a", map {
		my $line = $_;
		
		for my $fmt (qw(i b u)) {
			$line->{"fmt-$fmt"} |= ($block->{"fmt-$fmt"})
		}
		
		my $txt = $line->{'stl-pref'} . fmt::applyTextFmt($line, $line->{'text'}, \&fmtText);
		
		$txt = NFD($txt);
		
		$txt =~ y/\x{300}-\x{304}\x{306}-\x{308}\xc9\x{30a}\x{327}\xcc\x{30b}\x{328}\x{30c}/\xc1-\xcf/;
		$txt =~ s/([A-Za-z])([\xc1-\xc8\xca\xcb\xcd-\xcf])/\2\1/g;
		
		$txt =~ y/\xa0-\xa7\xa4\x{2018}\x{201c}\xab\x{2190}-\x{2193}/\xa0-\xaf/;
		$txt =~ y/\xb0-\xb3\xd7\xb5-\xb7\xf7\x{2019}\x{201d}\xbb-\xbf/\xb0-\xbf/;
		$txt =~ y/\x{2015}\xb9\xae\xa9\x{2122}\x{266a}\xac\xa6\x{215b}-\x{215e}/\xd0-\xd7\xdc-\xdf/;
		$txt =~ y/\x{2126}\xc6\x{110}\xaa\x{126}\xe5\x{132}\x{13f}\x{141}\xd8\x{152}\xba\xde\x{166}\x{14a}\x{149}/\xe0-\xef/;
		$txt =~ y/\x{138}\xe6\x{111}\xf0\x{127}\x{131}\x{133}\x{140}\x{142}\xf8\x{153}\xdf\xfe\x{167}\x{14b}\xad/\xf0-\xff/;
		
		$txt =~ s/[^\x00-\xff]//g;
		
		$txt
	} @{$block->{'textlines'}});
	
	$finalText = substr($finalText, 0, 111);
	
	my $l = 112 - length($finalText);
	
	$finalText .= ("\x8f" x $l);
	
	return $finalText;
}

#####
#
#####
sub displayTti {
	my ($block) = @_;
	
	if (!$block->{'skip'} and !common::textIsEmpty($block)) {
		#printf "%04d\t%s\t%s\n%s\n\n", ++$common::ID, # $block->{'index'}
		#	fmtTxtTime($block->{'start'}),
		#	fmtTxtTime($block->{'end'}),
		#	fmtTxtText($block);
	
		my $result = "";
		
		for my $pair (["SGN", "\x00"],
			["SN", showpac::encodeRevWord($common::ID++)],
			["EBN", "\xff"],
			["CS", "\x00"],
			["TCI", encodeTime($block->{'start'})],
			["TCO", encodeTime($block->{'end'})],
			["VP", "\x14"],
			["JC", "\x00"],
			["CF", "\x00"],
			["TF", encodeText($block), 1]
			) {
			$result .= printStlBytes($block, @$pair);
		}
		
		return $result;
	}
	else {
		return "";
	}
}

1;
