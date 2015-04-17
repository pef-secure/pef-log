package PEF::Log::Format::Yaml;
use YAML::XS;
use strict;
use warnings;

sub formatter {
	return sub {
		my ($level, $sublevel, $message) = @_;
		$message = {message => $message} if not ref $message;
		Dump $message;
	};
}

1;
