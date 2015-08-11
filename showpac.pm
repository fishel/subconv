package showpac;
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
sub dieNoPac {
	die("We can only convert from .pac to .pac with a changed text: @_;");
}

#####
#
#####
sub displayHead {
	my ($headInfo) = @_;
	
	unless (defined($headInfo->{'headPacBytes'})) {
		dieNoPac(1);
	}
	
	return $headInfo->{'headPacBytes'};
}

#####
#
#####
sub displayBlockPrefix {
	my ($block) = @_;
	
	unless (defined($block->{'staticPrefix'})) {
		dieNoPac(2);
	}
	
	return $block->{'staticPrefix'};
}

#####
#
#####
sub encodeRevWord {
	my ($x) = @_;
	
	my $x1 = $x % 256;
	my $x2 = ($x >> 8) % 256;
	
	return chr($x1) . chr($x2);
}

#####
#
#####
sub encodePacText {
	my ($txtEntry, $italicText) = @_;
	
	my $str = NFD($txtEntry->{'text'});
	
	if ($txtEntry->{'fmt-i'} or $italicText) {
		$str = "<" . $str . ">";
		$str =~ s/< +/</g;
		$str =~ s/ +>/>/g;
	}
	
	$str =~ y/\xa0ßæÆðĐœŒøØþÞªºđ¿¡/\xfb\x81\x7c\x5c\x89\x8c\xba\x9a\x7d\x5d\x87\x88\xa6\xa7\xae\xa8\xad/;
	
	$str =~ y/\x{303}\x{30a}\x{301}\x{300}\x{302}\x{308}\x{327}\x{30c}/\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7/;
	
	$str =~ s/(.)([\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7])/\2\1/g;
	
	$str =~ s/[^\x00-\xff]//g;
	
	return $str;
}

#####
#
#####
sub displayBlockText {
	my ($block) = @_;
	
	my $output = $block->{'techline'};
	
	for my $txtEntry (@{$block->{'textlines'}}) {
		unless (defined($txtEntry->{'pref'})) {
			#dieNoPac($block->{'index'});
			$txtEntry->{'pref'} = "\x09\x03";
		}
		
		$output .= "\xfe" . $txtEntry->{'pref'} . encodePacText($txtEntry, $block->{'fmt-i'});
	}
	
	return encodeRevWord(length($output)) . $output;
}

#####
#
#####
sub displayBlock {
	my ($block) = @_;
	
	my $result = displayBlockPrefix($block);
	
	$result .= displayBlockText($block);
	
	return $result;
}

#####
#
#####
sub displayTail {
	my ($block) = @_;
	
	return $block->{'finalPrint'};
}

1;
