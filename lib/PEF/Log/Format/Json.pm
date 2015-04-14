package PEF::Log::Format::Json;
use JSON;
use B;

use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $json = JSON->new->utf8;
	$json->allow_blessed(1);
	$json->convert_blessed(1);
	$json->pretty(1) if not exists $params{pretty} or not $params{pretty};
	bless {json => $json}, $class;
}

sub formatter {
	my $self = $_[0];
	return sub {
		my ($level, $sublevel, $message) = @_;
		$message = {message => $message} if not ref $message;
		no warnings 'once';
		local *UNIVERSAL::TO_JSON = sub {
			my $b_obj = B::svref_2object($_[0]);
			return $b_obj->isa("B::HV") ? {%{$_[0]}} : $b_obj->isa("B::AV") ? [@{$_[0]}] : undef;
		};
		$self->{json}->encode($message);
	};
}

1;
