package showsrt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;
use fmt;

#####
#
#####
sub fmtSrtTime {
	my ($time) = @_;
	
	return sprintf("%02d:%02d:%02d,%03d", $time->{'h'}, $time->{'m'}, $time->{'s'}, $time->{'ms'});
}

#####
#
#####
sub applySrtFormatting {
	my ($text, $fmt) = @_;
	
	if ($fmt =~ /^[ibu]$/) {
		return "<$fmt>$text</$fmt>";
	}
	else {
		return $text;
	}
}

#####
#
#####
sub fmtSrtText {
	my ($block) = @_;
	
	my $text = join("\n", grep /\S/, map {
			#line-level formatting
			fmt::applyTextFmt($_, common::trimText($_->{'text'}), \&applySrtFormatting)
		} @{$block->{'textlines'}});
	
	#segment-level formatting
	$text = fmt::applyTextFmt($block, $text, \&applySrtFormatting);
	
	return $text;
}

#####
#
#####
sub displayBlock {
	my ($block) = @_;
	
	if (!$block->{'skip'} and !common::textIsEmpty($block)) {
		return common::toUtf(sprintf("%d\n%s --> %s\n%s\n\n", ++$common::ID, #$block->{'index'}
			fmtSrtTime($block->{'start'}),
			fmtSrtTime($block->{'end'}),
			fmtSrtText($block)));
	}
	else {
		return "";
	}
}

1;
