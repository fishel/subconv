#!/usr/bin/perl
use strict;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);

BEGIN {
	unshift(@INC, $Bin);
}

use common;

use parse890;
use parsepac;
use parsetxt;
use parsesrt;
use parseebustl;
use parseebutt;

use showtxt;
use showsrt;
use showebutt;
use showebustl;
use showpac;
use show890;

our %headParseFuncMap = (
	'srt' => \&parsesrt::readHead,
	'txt' => \&parsetxt::readHead,
	'itf' => \&parsetxt::readHead,
	'pac' => \&parsepac::readHead,
	'890' => \&parse890::readHead,
	'xml' => \&parseebutt::readHead,
	'ebutt' => \&parseebutt::readHead,
	'stl' => \&parseebustl::readGsi,
	'ebustl' => \&parseebustl::readGsi
	);

our %blockParseFuncMap = (
	'srt' => \&parsesrt::readBlock,
	'txt' => \&parsetxt::readBlock,
	'itf' => \&parsetxt::readBlock,
	'pac' => \&parsepac::readBlock,
	'890' => \&parse890::readBlock,
	'xml' => \&parseebutt::readBlock,
	'ebutt' => \&parseebutt::readBlock,
	'ebustl' => \&parseebustl::readTti,
	'stl' => \&parseebustl::readTti
	);

our %headDisplayFuncMap = (
	'srt' => \&doNothing,
	'txt' => \&doNothing,
	'itf' => \&doNothing,
	'pac' => \&showpac::displayHead,
	'890' => \&show890::displayHead,
	'xml' => \&showebutt::displayHead,
	'ebutt' => \&showebutt::displayHead,
	'stl' => \&showebustl::displayGsi,
	'ebustl' => \&showebustl::displayGsi,
	'raw' => \&doNothing,
	'debug' => \&doNothing
	);

our %blockDisplayFuncMap = (
	'srt' => \&showsrt::displayBlock,
	'txt' => \&showtxt::displayBlock,
	'itf' => \&showtxt::displayBlock,
	'xml' => \&showebutt::displayBlock,
	'ebutt' => \&showebutt::displayBlock,
	'stl' => \&showebustl::displayTti,
	'ebustl' => \&showebustl::displayTti,
	'raw' => \&displayRawBlock,
	'debug' => \&displayDebugBlock,
	'pac' => \&showpac::displayBlock,
	'890' => \&show890::displayBlock
	);

our %tailDisplayFuncMap = (
	'srt' => \&doNothing,
	'txt' => \&doNothing,
	'itf' => \&doNothing,
	'pac' => \&showpac::displayTail,
	'890' => \&doNothing,
	'xml' => \&showebutt::displayTail,
	'ebutt' => \&showebutt::displayTail,
	'stl' => \&doNothing,
	'ebustl' => \&doNothing,
	'raw' => \&doNothing,
	'debug' => \&doNothing
	);

my ($fname, $inFmt, $outFmt, $substituteTextFile, $debug, $subNumLim) =
	handleArgsAndOptions();

my $subData = loadSubData($substituteTextFile);

my $result = tryParse($fname, $inFmt, $subData, $debug);

#try other input formats
unless ($result) {
	my @inFormats = grep { $_ ne $inFmt } keys %headParseFuncMap;
	
	for my $newInFmt (@inFormats) {
		$result = tryParse($fname, $newInFmt, $subData);
		
		if ($result) {
			last;
		}
	}
}

if ($subNumLim > 0) {
	$result->{'blocklist'} = [@{$result->{'blocklist'}}[0..($subNumLim-1)]];
}

if ($result) {
	binmode(STDOUT);
	print common::display($result,
		getFunc(\%headDisplayFuncMap, $outFmt),
		getFunc(\%blockDisplayFuncMap, $outFmt),
		getFunc(\%tailDisplayFuncMap, $outFmt));
}
else {
	die("Failed to convert `$fname'");
}

#####
#
#####
sub tryParse {
	my ($fname, $inFmt, $subData, $debug) = @_;
	
	our $data = undef;
	
	eval {
		$data = common::parse($fname, $subData,
			getFunc(\%headParseFuncMap, $inFmt),
			getFunc(\%blockParseFuncMap, $inFmt));
	};
	
	if ($@) {
		if ($debug) {
			print "ERROR: $@;\n";
		}
		return undef;
	}
	else {
		return $data;
	}
}

#####
#
#####
sub loadSubData {
	my ($subFName) = @_;
	
	if ($subFName) {
		my $subData = common::parse($subFName, undef, \&parsetxt::readHead, \&parsetxt::readBlock,
			\&doNothing, \&doNothing, \&doNothing);
		return $subData->{'blocklist'};
	}
	else {
		return undef;
	}
}

#####
#
#####
sub getFunc {
	my ($map, $key) = @_;
	
	my $result = $map->{$key};
	
	unless (defined($result)) {
		die("Unknown format `$key'");
	}
	
	return $result;
}

#####
#
#####
sub getInputFormatFromExtension {
	my ($filename) = @_;
	
	my @fields = split(/\./, $filename);
	
	my $result = lc($fields[$#fields]);
	
	return $result;
}

#####
#
#####
sub handleArgsAndOptions {
	my ($inFmt, $outFmt, $substituteTextFile, $debug, $lim);
	
	GetOptions(
		'd' => \$debug,
		'i=s' => \$inFmt,
		'o=s' => \$outFmt,
		'l=n' => \$lim,
		't=s' => \$substituteTextFile) or die("Opts failed");

	my $fname = shift @ARGV;
	
	if (!$fname) {
		die("Give me a file");
	}
	elsif (@ARGV > 0) {
		die("Give me just 1 file");
	}
	
	if (!$lim) {
		$lim = 0;
	}
	
	unless ($inFmt) {
		$inFmt = getInputFormatFromExtension($fname);
	}
	
	unless ($outFmt) {
		$outFmt = 'txt';
	}
	
	return ($fname, $inFmt, $outFmt, $substituteTextFile, $debug, $lim);
}

#####
#
#####
sub doNothing {
	#do nothing
}

#####
#
#####
sub displayRawBlock {
	my ($block) = @_;
	
	return join(" ", map { trimText($_->{'text'}) } @{$block->{'textlines'}}) . "\n";
}

#####
#
#####
sub displayDebugBlock {
	my ($block) = @_;
	
	return Dumper($block);
}
