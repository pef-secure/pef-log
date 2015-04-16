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

sub new {
	my ($class, %params) = @_;
	my $value_dumper = PEF::Log::Stringify::DumpAll->new(1);
	my %formatters;
	$params{short_message} ||= $params{short};
	$params{full_message}  ||= $params{full};
	$params{short_message} ||= "%50m";
	$params{full_message}  ||= "[%l]: %m";
	$params{host}          ||= "misconfigured.localhost";
	my %std           = map { $_ => $params{$_} } qw(short_message full_message host);
	my $format_fields = \%std;
	my $key_prefix    = "";
	my $make_fmt      = sub {
		for my $key (keys %$format_fields) {
			my $rf = $key_prefix . $key;
			$rf = "_" . $rf if $rf eq '_id';
			if ($format_fields->{$key}) {
				if (index ($format_fields->{$key}, '%') != -1) {
					if ($rf eq 'full_message') {
						$formatters{$rf} = PEF::Log::Format::Pattern->new(
							format    => $format_fields->{$key},
							multiline => $params{multiline}
						)->formatter();
					} else {
						$formatters{$rf} =
						  PEF::Log::Format::Pattern->new(format => $format_fields->{$key})->formatter();
					}
				} else {
					my $value = $value_dumper->stringify($format_fields->{$key});
					$formatters{$rf} = eval <<SHF
			sub { "$value" }
SHF
				}
			} else {
				$formatters{$rf} = sub { "" };
			}
		}
	};
	$make_fmt->();
	if (exists $params{extra}) {
		$format_fields = $params{extra};
		$key_prefix    = "_";
		$make_fmt->();
	}
	bless {
		value_dumper => $value_dumper,
		fields       => \%formatters
	}, $class;
}

sub formatter {
	my $self = $_[0];
	return sub {
		my ($level, $sublevel, $message) = @_;
		my $gelf = {
			version   => "1.1",
			timestamp => time,
			level     => $level_map{$level},
			map { $_ => $self->{fields}{$_}->($level, $sublevel, $message) } keys %{$self->{fields}}
		};
		encode_json $gelf;
	};
}

1;
