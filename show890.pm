package show890;
use strict;
use utf8;
use Unicode::Normalize;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

#####
#
#####
sub dieNo890 {
	die("We can only convert from .890 to .890 with a changed text");
}

#####
#
#####
sub displayHead {
	my ($headInfo) = @_;
	
	unless (defined($headInfo->{'head'})) {
		dieNo890();
	}
	
	return $headInfo->{'head'};
}

#####
#
#####
sub fmtLine {
	my ($italic, $text) = @_;
	
	if ($italic) {
		$text = "\x88" . $text . "\x98";
	}
	
	return $text;
}

#####
#
#####
sub encodeLine {
	my ($text) = @_;
	
	$text =~ s/<i>/\x88/g;
	$text =~ s/<\/i>/\x98/g;
	
	$text =~ y/©°―ªº²/\xa8\xac\xbe\xa6\x05\x15/;
	$text =~ y/\xa0\x{201c}\xabĐðÞþ/\x0b\x1a\x14\x02\x12\x03\x13/;
	$text =~ y/ŒœØøÆæßÇçÅå/\x07\x17\x1f\x1c\x1e\x1b\x0e\x01\x11\]\x1d/;
	
	$text = NFD($text);
	
	$text =~ y/\x{300}\x{301}\x{302}\x{303}\x{308}\x{327}\x{30c}\x{308}\x{30a}/\x81\x82\x83\x85\x86\x87\x89\x8a\x8c/;
	$text =~ s/(.)([\x81\x82\x83\x85\x86\x87\x89\x8a\x8c])/\2\1/g;
	
	$text =~ s/[^\x00-\xff]//g;
	
	my $l = 51 - length($text);
	
	if ($l > 0) {
		$text .= ("\x7f" x $l);
	}
	
	return substr($text, 0, 51);
}

#####
#
#####
sub encodeLines {
	my ($block) = @_;
	
	my ($txt1, $txt2) = map { my $entry = $_; fmtLine(($entry->{'fmt-i'} or $block->{'fmt-i'}), $entry->{'text'}) } @{$block->{'textlines'}};
	
	if (length($txt1) > 51) {
		if (substr($txt1, 0, 52) =~ /^(.*) [^ ]*$/) {
			my $newTxt1 = $1;
			$txt2 = substr($txt1, length($newTxt1)) . " " . $txt2;
			$txt1 = $newTxt1;
		}
		else {
			$txt2 = substr($txt1, 51);
		}
	}
	
	return (encodeLine($txt1), encodeLine($txt2));
}

#####
#
#####
sub displayBlock {
	my ($block) = @_;
	
	unless (defined($block->{'preBytes'}) and defined($block->{'interBytes'})) {
		dieNo890();
	}
	
	my ($encl1, $encl2) = encodeLines($block);
	
	return $block->{'preBytes'} . $encl1 . $block->{'interBytes'} . $encl2;
}

1;
