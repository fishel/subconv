package showebutt;
use strict;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;
use showtxt;

#####
#
#####
sub fmtEbuTTTime {
	my ($time) = @_;
	
	return showtxt::fmtTxtTime($time); # same format for TXT and EBU TT
}

#####
#
#####
sub hasFormatting {
	my ($struc) = @_;
	
	for my $fmt (qw(i b u)) {
		if ($struc->{"fmt-" . $fmt}) {
			return 1;
		}
	}
	
	return undef;
}

#####
#
#####
sub getEbuTTFmtList {
	my ($lineEntry) = @_;
	
	return join(" ", grep { $lineEntry->{$_} } map { "fmt-" . $_ } qw(i b u));
}

#####
#
#####
sub applyEbuTTFmt {
	my ($lineEntry) = @_;
	
	if (hasFormatting($lineEntry)) {
		my $fmtList = getEbuTTFmtList($lineEntry);
		
		return "<span style=\"$fmtList\">" . $lineEntry->{'text'} . "</span>";
	}
	else {
		return $lineEntry->{'text'};
	}
}

#####
#
#####
sub fmtEbuTTText {
	my ($block) = @_;
	
	my $result = join("<br\/>\n\t\t\t\t", map { applyEbuTTFmt(common::trimText($_)) } @{$block->{'textlines'}});
	
	return $result;
}

#####
#
#####
sub displayBlock {
	my ($block) = @_;
	
	my $style = "";
	
	if (hasFormatting($block)) {
		my $fmtList = getEbuTTFmtList($block);
		
		$style = " style=\"$fmtList\"";
	}
	
	if (!$block->{'skip'} and !common::textIsEmpty($block)) {
		return common::toUtf(sprintf("\t\t\t<p$style xml:id=\"p%d\" begin=\"%s\" end=\"%s\">\n\t\t\t\t%s\n\t\t\t<\/p>\n", ++$common::ID,# $block->{'index'},
			fmtEbuTTTime($block->{'start'}),
			fmtEbuTTTime($block->{'end'}),
			fmtEbuTTText($block)));
	}
	else {
		return "";
	}
}

#####
#
#####
sub displayHead {
	my ($headInfo, $lang) = @_;
	
	unless ($lang) {
		$lang = "en";
	}
	
	return
"<?xml version=\"1.0\"?>
<tt xmlns=\"http://www.w3.org/ns/ttml\"
      xmlns:ttp=\"http://www.w3.org/ns/ttml#parameter\"
      xmlns:tts=\"http://www.w3.org/ns/ttml#styling\"
      xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\"
      xml:lang=\"$lang\"
      ttp:timeBase=\"smpte\">
	<head>

		<metadata>
			<ebuttm:documentMetadata>
				<ebuttm:documentEbuttVersion>v1.0</ebuttm:documentEbuttVersion>
			</ebuttm:documentMetadata>
		</metadata>

		<styling>
			<style xml:id=\"defaultStyle\"/>
			<style xml:id=\"fmt-i\" tts:fontStyle=\"italic\" />
			<style xml:id=\"fmt-u\" tts:textDecoration=\"underline\" />
			<style xml:id=\"fmt-b\" tts:fontWeight=\"bold\" />
		</styling>

		<layout>
			<region xml:id=\"defaultRegion\" tts:origin=\"10% 80%\" tts:extent=\"80% 15%\" tts:style=\"defaultStyle\">
		</layout>
	</head>

	<body>
		<div>\n";
}

#####
#
#####
sub displayTail {
	return "\t\t</div>\n\t</body>\n</tt>\n";
}

1;
