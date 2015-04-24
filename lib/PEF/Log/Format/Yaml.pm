package PEF::Log::Format::Yaml;
use YAML::XS;
use strict;
use warnings;

sub formatter {
	return sub {
		my ($level, $stream, $message) = @_;
		$message = [$message] if not ref $message;
		Dump $message;
	};
}

1;
