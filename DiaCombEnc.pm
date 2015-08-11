package DiaCombEnc;
use strict;
use Unicode::Normalize;
use base qw(Encode::Encoding);

sub newEncObj {
	my $self = { 'name' => 'diacombenc' };
	
	bless $self;
	
	return $self;
}

sub encode($$;$) {
	my ($self, $text, $check) = @_;
	die("encoding with this encoding is not meant to work");
}

sub decode($$;$) {
	my ($self, $text, $check) = @_;
	$text =~ y/\xa8\xb0\xb4\xb8\xaf/\x{308}\x{30a}\x{301}\x{327}\x{304}/;
	return NFC($text);
}

sub name {

}

1;
