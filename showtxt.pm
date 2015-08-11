package showtxt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;

#####
#
#####
sub fmtTxtTime {
	my ($time) = @_;
	
	return sprintf("%02d:%02d:%02d:%02d", $time->{'h'}, $time->{'m'}, $time->{'s'}, $time->{'f'});
}

#####
#
#####
sub fmtTxtText {
	my ($block) = @_;
	
	return join("\n", grep /\S/, map { common::trimText($_->{'text'}) } @{$block->{'textlines'}});
}

#####
#
#####
sub displayBlock {
	my ($block) = @_;
	
	if (!$block->{'skip'} and !common::textIsEmpty($block)) {
		return common::toUtf(sprintf("%04d\t%s\t%s\n%s\n\n", ++$common::ID, # $block->{'index'}
			fmtTxtTime($block->{'start'}),
			fmtTxtTime($block->{'end'}),
			fmtTxtText($block)));
	}
	else {
		return "";
	}
}

1;
