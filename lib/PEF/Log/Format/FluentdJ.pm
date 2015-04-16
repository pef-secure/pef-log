package PEF::Log::Format::FluentdJ;
use base 'PEF::Log::Format::Json';
use PEF::Log::Format::Pattern;
use PEF::Log::Stringify::DumpAll;
use JSON;
use Time::HiRes qw(time);
use Scalar::Util qw(blessed);
use Carp;
use strict;
use warnings;
use feature 'state';

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params);
	$self->{json}->pretty(0);
	$self->{need_nl} ||= "\n";
	if ($params{container}) {
		$self->{container} = $params{container};
	} elsif ($params{format}) {
		$self->{formatter} = PEF::Log::Format::Pattern->new(format => $params{format})->formatter();
	} else {
		$self->{formatter} = sub {
			my ($level, $sublevel, $message) = @_;
			"[$level]: $message";
		};
	}
	$params{tag} ||= "%l";
	my $value_dumper = PEF::Log::Stringify::DumpAll->new(1);
	$self->{value_dumper} = $value_dumper;
	if (index ($params{tag}, '%') != -1) {
		$self->{tag} = PEF::Log::Format::Pattern->new(format => $params{tag})->formatter();
	} else {
		my $value = $value_dumper->stringify($params{tag});
		$self->{tag} = eval <<SHF
		sub { $value }
SHF
	}
	$self;
}

sub formatter {
	my $self = $_[0];
	state $prefix = "PEF::Log::Format::Flags::";
	return sub {
		my ($level, $sublevel, $message) = @_;
		my $msg;
		my $json_encoded;
		if ($self->{formatter}) {
			$msg = $self->{formatter}->($level, $sublevel, $message);
			$json_encoded = 0;
		} else {
			no warnings 'once';
			my $formatter = $PEF::Log::Config::config{formats}{$self->{container}};
			if (!$formatter) {
				$message = "misconfigured container: $self->{container}";
				$formatter = sub { $_[2] };
				carp "misconfigured container: $self->{container}";
			}
			my $bf = blessed($formatter);
			if ($bf && substr ($bf, 0, length $prefix) eq $prefix) {
				my @flags = split /:/, substr ($bf, length $prefix);
				$json_encoded = (grep { $_ eq 'JSON' } @flags) ? 1 : 0;
			}
			$msg = $formatter->($level, $sublevel, $message);
		}
		my $tag = $self->{tag}->($level, $sublevel, $message);
		my $ret;
		if ($json_encoded) {
			$ret = "[" . $self->{value_dumper}->stringify($tag) . "," . time . ",$msg]";
		} else {
			$ret = encode_json [$tag, time, $msg];
		}
		$ret;
	};
}

1;
