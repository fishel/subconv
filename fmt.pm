package fmt;
use strict;

#####
#
#####
sub applyTextFmt {
	my ($struc, $text, $fmtFunc) = @_;
	
	for my $fmt (qw(i b u)) {
		if ($struc->{"fmt-$fmt"}) {
			$text = &$fmtFunc($text, $fmt);
		}
	}
	
	return $text;
}

#####
#
#####
sub genTagRe {
	my $result = join("|", map { quotemeta $_ } @_);
	
	return $result;
}

#####
#
#####
sub genOpeningTagRe {
	my ($tagDef) = @_;
	
	my $result = genTagRe(keys %{$tagDef->{'tags'}});
	
	return $result;
}

#####
#
#####
sub genClosingTagRe {
	my ($tagDef) = @_;
	
	my $tags = $tagDef->{'tags'};
	
	my $result = genTagRe(map { $tags->{$_}->{'closingTag'} } keys %$tags);
	
	return $result;
}

#####
#
#####
sub hasTags {
	my ($text, $tagDef) = @_;
	
	my $tagRe = $tagDef->{'all_re'};
	
	my $result = ($text =~ /($tagRe)/);
	
	return $result;
}

#####
#
#####
sub removeFmtTags {
	my ($struc, $tagDef) = @_;
	
	my $tagRe = $tagDef->{'all_re'};
	
	for my $lineEntry (@{$struc->{'textlines'}}) {
		$lineEntry->{'text'} =~ s/(\S)($tagRe)(\S)/\1 \3/g;
		$lineEntry->{'text'} =~ s/($tagRe)//g;
	}
}

#####
#
#####
sub detectFmtTag {
	my ($text, $tagDef, $skipLeft, $skipRight) = @_;
	
	#failsafe
	if ($skipLeft and $skipRight) {
		die("Fail");
	}
	
	#basic regexp
	my $regExp = "(.*)";
	
	#skipping or keeping left tag detection?
	if ($skipLeft) {
		$regExp = "()()$regExp";
	}
	else {
		my $openingTagRe = $tagDef->{'opening_re'};
		my $dialogueDashRe = ($skipRight? "": "\\s*-?\\s*");
		
		$regExp = "^($dialogueDashRe)(" . $openingTagRe . ")" . $regExp;
	}
	
	#skipping or keeping right tag detection?
	unless ($skipRight) {
		my $closingTagRe = $tagDef->{'closing_re'};
		
		$regExp .= "(" . $closingTagRe . ")\\s*\$";
	}
	
	#applying
	if ($text =~ /$regExp/) {
		my ($dash, $openingTag, $changedLine, $closingTag) = ($1, $2, $3, $4);
		
		my $fmt = ($skipLeft? $tagDef->{'cltags'}->{$closingTag}->{'fmt'}: $tagDef->{'tags'}->{$openingTag}->{'fmt'});
		
		#check if the same tag was detected on the left and right
		if (!$skipLeft and !$skipRight and $tagDef->{'tags'}->{$openingTag}->{'closingTag'} ne $closingTag) {
			return undef;
		}
		else {
			my $spaceInBetween = (($dash =~ /\S$/ and $changedLine =~ /^\S/)? " ": "");
			my $result = { 'changedLine' => ($dash . $spaceInBetween . $changedLine), 'formatId' => $fmt };
			return $result;
		}
	}
	else {
		return undef;
	}
}

#####
#
#####
sub processTextLevelFmtTags {
	my ($struc, $tagDef) = @_;
	
	my $lines = $struc->{'textlines'};
	
	unless (scalar @$lines > 1) {
		return;
	}
	
	my ($firstLine, $lastLine) = ($lines->[0]->{'text'}, $lines->[$#$lines]->{'text'});
	my ($firstRes, $lastRes, $tmpStruc);
	
	#remove the left-side and right-side tags
	while ($firstRes = detectFmtTag($firstLine, $tagDef, undef, 1) and $lastRes = detectFmtTag($lastLine, $tagDef, 1, undef) and ($firstRes->{'formatId'} eq $lastRes->{'formatId'})) {
		$tmpStruc->{"fmt-" . $firstRes->{'formatId'}} = 1;
		
		$firstLine = $firstRes->{'changedLine'};
		$lastLine = $lastRes->{'changedLine'};
	}
	
	my $fullText = join("", $firstLine, (map { $_->{'text'} } @$lines[1..($#$lines-1)]), $lastLine);
	
	#check if the inside has any tags -- if it does, the whole removal might be compromised,
	#in which case detection is cancelled
	unless (hasTags($fullText, $tagDef)) {
		$lines->[0]->{'text'} = $firstLine;
		$lines->[$#$lines]->{'text'} = $lastLine;
		
		for my $k (keys %$tmpStruc) {
			$struc->{$k} = 1;
		}
	}
}

#####
#
#####
sub processLineLevelFmtTags {
	my ($struc, $tagDef) = @_;
	
	for my $lineEntry (@{$struc->{'textlines'}}) {
		my $changedLine = $lineEntry->{'text'};
		my $tmpStruc;
		
		while (my $fmtDetResults = detectFmtTag($changedLine, $tagDef)) {
			$tmpStruc->{"fmt-" . $fmtDetResults->{'formatId'}} = 1;
			$changedLine = $fmtDetResults->{'changedLine'};
		}
		
		#check if the inside has any tags -- if so, the whole removal might be compromised,
		#in which case detection is cancelled
		unless (hasTags($changedLine, $tagDef)) {
			$lineEntry->{'text'} = $changedLine;
			
			for my $k (keys %$tmpStruc) {
				$lineEntry->{$k} = 1;
			}
		}
	}
}

#####
#
#####
sub fmtTagDef {
	my $result = {};
	
	for my $tuple (@_) {
		$result->{'tags'}->{$tuple->[1]} = { 'fmt' => $tuple->[0], 'closingTag' => $tuple->[2] };
		$result->{'cltags'}->{$tuple->[2]} = { 'fmt' => $tuple->[0], 'openingTag' => $tuple->[1] };
	}
	
	$result->{'opening_re'} = genOpeningTagRe($result);
	$result->{'closing_re'} = genClosingTagRe($result);
	$result->{'all_re'} = $result->{'opening_re'} . "|" . $result->{'closing_re'};
	
	return $result;
}

#####
#
#####
sub sortOutTags {
	my ($struc, @rawTagTuples) = @_;
	
	my $tagDef = fmtTagDef(@rawTagTuples);
	
	#text-level must be done before line-level
	processTextLevelFmtTags($struc, $tagDef);
	
	processLineLevelFmtTags($struc, $tagDef);
	
	removeFmtTags($struc, $tagDef);
}

1;
