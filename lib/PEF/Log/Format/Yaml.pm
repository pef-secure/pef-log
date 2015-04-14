package PEF::Log::Format::Yaml;
use YAML::XS;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	bless \(my $a), $class;
}

sub formatter {
	my $self = $_[0];
	return sub {
		my ($level, $sublevel, $message) = @_;
		$message = {message => $message} if not ref $message;
		Dump $message;
	};
}

1;
