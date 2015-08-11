package common;
use strict;
use Encode;
use Encode::Guess;
use Encode::Encoding;
use utf8;
use Getopt::Long;
use DiaCombEnc;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

our $ID;

#####
#
#####
sub parse {
	my ($fname, $subData, $readHeader, $readBlock) = @_;
	
	my @savedBlockList = ();

	my $fh;
	open($fh, $fname) or die("Failed to open `$fname'");
	
	#read head
	my $headInfo = &$readHeader($fh);
	
	#print STDERR "head;\n";
	
	my $block;
	
	#read blocks
	while ($block = &$readBlock($fh, $headInfo)) {
		#print STDERR "block;\n";
		
		checkTimes($block);
		
		if ($subData and !textIsEmpty($block) and @$subData > 0) {
			my $subBlock = shift @$subData;
			
			mutilateBlock($block, $subBlock);
		}
		
		push @savedBlockList, $block;
	}
	
	close($fh);
	
	return { 'head' => $headInfo, 'blocklist' => \@savedBlockList };
}

#####
#
#####
sub display {
	my ($data, $displayHeader, $displayBlock, $displayTail) = @_;
	
	my $result = "";
	
	#display head
	$result .= &$displayHeader($data->{'head'}, (scalar @{$data->{'blocklist'}}));
	
	for my $block (@{$data->{'blocklist'}}) {
		#display block
		$result .= &$displayBlock($block);
	}
	
	#display tail
	$result .= &$displayTail();
	
	return $result;
}

#####
#
#####
sub mutilateBlock {
	my ($block, $subBlock) = @_;
	
	my $subSize = $#{$subBlock->{'textlines'}};
	my $size = $#{$block->{'textlines'}};
	
	delete @{$block->{'textlines'}}[($subSize+1)..$size];
	
	for my $i (0..$subSize) {
		$block->{'textlines'}->[$i]->{'text'} = $subBlock->{'textlines'}->[$i]->{'text'};
	}
}

#####
#
#####
sub checkTime {
	my ($time) = @_;
	
	my($f, $s, $m, $h) = ($time->{'f'}, $time->{'s'}, $time->{'m'}, $time->{'h'});
	
	return ($f >= 0 and $f < 30 and
		 $s >= 0 and $s < 60 and
		 $m >= 0 and $m < 60);
}

#####
#
#####
sub checkTimes {
	my ($block) = @_;
	
	my $check = checkTime($block->{'start'});
	
	if ($check) {
		$check = checkTime($block->{'end'});
	}
	
	if (!$check) {
		die("Bad time parse (probably wrong format)");
	}
}

#####
#
#####
sub hexlog {
	my ($str) = @_;
	
	my $len = length($str);
	
	print "LOG: $str\n";
	for my $i (0..($len-1)) {
		printf "\\x%x", ord(substr($str, $i, 1));
	}
	print "\n";
}

#####
#
#####
sub readNbytes {
	my ($fh, $n, $dontDie) = @_;
	
	my $buf;
	my $num = read($fh, $buf, $n);
	
	if (defined($num) and $num < $n) {
		if ($dontDie) {
			return undef;
		}
		else {
			close(STDOUT);
			die("Tried to read `$n' bytes, but only got `$num' -- maybe this is not the expected format");
		}
	}
	elsif (!defined($num)) {
		close(STDOUT);
		die("Failed to read from file");
	}
	
	return $buf;
}

#####
#
#####
sub encDecode {
	my ($text, $enc) = @_;
	
	return decode($enc, $text);
}

#####
#
#####
sub guessDecode {
	my ($text) = @_;
	
	Encode::define_encoding(DiaCombEnc->newEncObj(), 'diacombenc');
	
	$text =~ s/\x0d\x00\x0d\x0a\x00/\x0d\x00\x0a\x00/g;
	$text =~ s/\x0d\x0a\x00\x0d\x0a\x00/\x0d\x00\x0a\x00/g;
	
	my ($utfText, $encName) = checkForBom($text);
	
	if (!defined($encName)) {
		Encode::Guess->add_suspects(qw/latin1 cp1250 cp1252/);
		
		my $decoder = Encode::Guess->guess($text);
		
		if (ref($decoder)) {
			$encName = $decoder->name;
			
			#print STDERR "unique: $encName;\n";
			
			$utfText = encDecode($text, $encName);
			($utfText, $encName) = ($decoder->decode($text), $decoder->name);
		}
		else {
			#print STDERR "ambigous: $decoder (or diacombenc);\n";
			
			my $bestNr = 1e6;
			
			if ($decoder =~ / or /) {
				for my $enc('diacombenc', split(/ or /, $decoder)) {
					my $currtxt = encDecode($text, $enc);
					
					my $len = length($currtxt);
					
					my $currNr = nrOfBadChars($currtxt);
					
					#print STDERR "enc $enc, bad $currNr, len $len;\n";
					
					if ($currNr <= $bestNr) {
						#print STDERR "---- selected\n";
						$bestNr = $currNr;
						$utfText = $currtxt;
						$encName = $enc;
					}
				}
			}
			
			if (!defined($utfText)) {
				die ($decoder);
			}
		}
	}
	
	if ($encName =~ /^UTF-16/ and $utfText =~ /\x{a0d}$/) {
		chop $utfText;
	}
	
	#print STDERR "final: $encName; $utfText";
	
	return ($utfText, $encName);
}

#####
#
#####
sub nrOfBadChars {
	my ($txt) = @_;
	
	$txt =~ s/[a-z0-9[:punct:][:space:]äöüõšžčćåôéîçéèíáôâêĳÿďđŕřĺł¿]//gi;
	
	my %charset = map { "" . $_ . " (" . ord($_) . ")" => 1 } split(//, $txt);
	return scalar keys %charset;
	
	#return length($txt);
}

#####
#
#####
sub checkForBom {
	my ($text) = @_;
	
	my $enc = undef;
	
	if ($text =~ /^\xff\xfe/) {
		$enc = 'UTF-16LE';
		$text = substr($text, 2);
	}
	elsif ($text =~ /^\xfe\xff/) {
		$enc = 'UTF-16BE';
		$text = substr($text, 2);
	}
	elsif ($text =~ /^\xef\xbb\xbf/) {
		$enc = 'UTF8';
		$text = substr($text, 3);
	}
	
	if (defined($enc)) {
		#print STDERR "trivial: $enc\n";
		return (decode($enc, $text), $enc);
	}
	else {
		return undef;
	}
}

#####
#
#####
sub tohex {
	my ($str) = @_;
	my $result = "";
	
	for my $x (0..(length($str) - 1)) {
		$result .= sprintf("\\x%02x", ord(substr($str, $x, 1)));
	}
	
	return $result;
}

#####
#
#####
sub textIsEmpty {
	my ($block) = @_;
	
	for my $line (@{$block->{'textlines'}}) {
		if ($line->{'text'} =~ /\S/) {
			return undef;
		}
	}
	
	return 1;
}

#####
#
#####
sub toUtf {
	my ($text) = @_;
	
	return encode('UTF-8', $text);
}

#####
#
#####
sub trimText {
	my ($txt) = @_;
	
	$txt =~ s/\s+/ /g;
	$txt =~ s/^ //g;
	$txt =~ s/ $//g;
	
	return $txt;
}

1;
