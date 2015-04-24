package PEF::Log::Format::Gelf;
use PEF::Log::Stringify::DumpAll;
use PEF::Log::Format::Pattern;
use JSON;
use Time::HiRes qw(time);

use strict;
use warnings;
# Syslog Levels for Reference
# 0 Emergency: system is unusable
# 1 Alert: action must be taken immediately
# 2 Critical: critical conditions
# 3 Error: error conditions
# 4 Warning: warning conditions
# 5 Notice: normal but significant condition
# 6 Informational: informational messages
# 7 Debug: debug-level messages

our %level_map = (
	debug    => 7,
	info     => 6,
	warning  => 4,
	error    => 3,
	critical => 2,
	fatal    => 1,
	deadly   => 0
);

sub formatter {
	my ($class, $params) = @_;
	my $value_dumper = PEF::Log::Stringify::DumpAll->new(1);
	my %formatters;
	my %std = (
		short_message => $params->{short_message} || $params->{short} || "%.50m",
		full_message  => $params->{full_message}  || $params->{full}  || "[%l]: %m",
		host          => $params->{host}          || "misconfigured.localhost"
	);
	my $format_fields = \%std;
	my $key_prefix    = "";
	my $make_fmt      = sub {
		for my $key (keys %$format_fields) {
			my $rf = $key_prefix . $key;
			$rf = "_" . $rf if $rf eq '_id';
			if ($format_fields->{$key}) {
				if (index ($format_fields->{$key}, '%') != -1) {
					if ($rf eq 'full_message') {
						$formatters{$rf} = PEF::Log::Format::Pattern->formatter(
							{   format    => $format_fields->{$key},
								multiline => $params->{multiline}
							}
						);
					} else {
						$formatters{$rf} =
						  PEF::Log::Format::Pattern->formatter({format => $format_fields->{$key}});
					}
				} else {
					my $value = $format_fields->{$key};
					$formatters{$rf} = sub { $value };
				}
			} else {
				$formatters{$rf} = sub { "" };
			}
		}
	};
	$make_fmt->();
	if (exists $params->{extra}) {
		$format_fields = $params->{extra};
		$key_prefix    = "_";
		$make_fmt->();
	}
	return bless sub {
		my ($level, $stream, $message) = @_;
		my $gelf = {
			version   => "1.1",
			timestamp => time,
			level     => $level_map{$level},
			map { $_ => $formatters{$_}->($level, $stream, $message) } keys %formatters
		};
		encode_json $gelf;
	}, "PEF::Log::Format::Flags::JSON:GELF";
}

1;
