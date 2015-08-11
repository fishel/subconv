package parsetxt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;

#####
#
#####
sub readHead {
	my ($fh, $preSpecEnc) = @_;
	
	my @lines = <$fh>;
	
	my $text = join("", @lines);
	
	my ($decText, $enc);
	
	if ($preSpecEnc) {
		($decText, $enc) = (common::encDecode($text, $preSpecEnc), $preSpecEnc);
	}
	else {
		($decText, $enc) = common::guessDecode($text);
	}
	
	my @decLines = split(/\n/, $decText);
	
	close($fh);
	
	return { 'lines' => \@decLines, 'pos' => 0 };
}

#####
#
#####
sub readBlock {
	my ($fh, $aux) = @_;
	my $arr = $aux->{'lines'};
	
	if ($aux->{'pos'} > $#$arr) {
		return undef;
	}
	
	my $block = readIndexLine($arr, $aux);
	
	if (!$block) {
		die("Failed to read block, probably not a .txt format");
	}
	
	$aux->{'pos'}++;
	
	my @lines = ();
	
	while ($aux->{'pos'} <= $#$arr and !readIndexLine($arr, $aux)) {
		my $textline = $arr->[$aux->{'pos'}++];
		
		$textline =~ s/\r//g;
		$textline =~ s/\x91/'/g;
		
		push @lines, $textline;
	}
	
	$block->{'textlines'} = [ map { 'text' => $_ }, @lines ];
	
	return $block;
}

#####
#
#####
sub readIndexLine {
	#my ($str) = @_;
	my ($arr, $aux) = @_;
	
	my $str = $arr->[$aux->{'pos'}];
	
	if ($str =~ /^\s*$/) {
		$str = $arr->[++$aux->{'pos'}];
	}
	
	if ($str =~ /^\[[0-9]+\]\s*$/) {
		$aux->{'pos'}++;
		$str = "0001\t" . $arr->[$aux->{'pos'}];
	}
	
	$str =~ s/\t[0-9]{2}:[0-9]{2}\s*$//g;
	
	if ($str =~ /^\s*(?:(?:SUBTITLE: )?\[?(\d+)\]?\s+)?(?:TIMEIN: )?(\d\d):(\d\d):(\d\d):(\d\d)\s+(?:(?:DURATION: )?(?:00:)?(?:00:)?\d\d:\d\d\s+)?(?:TIMEOUT: )?(\d\d):(\d\d):(\d\d):(\d\d)\s*$/) {
		return {
			'index' => 0 + $1,
			'start' => {
				'h' => $2,
				'm' => $3,
				's' => $4,
				'f' => $5,
				'ms' => $5 * 40
			},
			'end' => {
				'h' => $6,
				'm' => $7,
				's' => $8,
				'f' => $9,
				'ms' => $9 * 40
			}
		};
	}
	elsif ($str =~ /^\s*(?:(?:SUBTITLE: )?\[?(\d+)\]?\s+)?(?:TIMEIN: )?(\d\d):(\d\d):(\d\d):(\d\d)\s+(?:DURATION: )?(?:00:)?(?:00:)?(\d\d):(\d\d)\s+\s*$/) {
		my ($idx, $sh, $sm, $ss, $sf) = ($1, $2, $3, $4, $5);
		my ($durs, $durf) = ($6, $7);
		my ($fh, $fm, $fs, $ff) = ($sh, $sm, $ss + $durs, $sf + $durf);
		
		if ($ff > 23) {
			$fs += int($ff/24);
			$ff = $ff % 24;
		}
		if ($fs > 59) {
			$fm += int($fs / 60);
			$fs = $fs % 60;
		}
		if ($fm > 59) {
			$fh += int($fm / 60);
			$fm = $fm % 60;
		}

		return {
			'index' => 0 + $idx,
			'start' => {
				'h' => $sh,
				'm' => $sm,
				's' => $ss,
				'f' => $sf,
				'ms' => $sf * 40
			},
			'end' => {
				'h' => $fh,
				'm' => $fm,
				's' => $fs,
				'f' => $ff,
				'ms' => $ff * 40
			}
		};
	}
	else {
		return undef;
	}
}

1;
