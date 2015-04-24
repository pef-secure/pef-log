package PEF::Log::Appender;
use Carp;
use Clone 'clone';
use strict;
use warnings;

# typical params are:
#    out:    -- output stream or file
#    format: -- name of format
#    filter: -- user supplied message transformation filter

sub new {
	my ($class, %params) = @_;
	my $self = {%params};
	bless $self, $class;
}

sub _reload {
	my ($self, $params) = @_;
	if (exists ($params->{filter}) && $params->{filter}) {
		eval "use $params->{filter}";
		croak $@ if $@;
		$self->{filter} = "$params->{filter}"->new($params);
	}
	if (exists ($params->{format}) && $params->{format}) {
		no warnings 'once';
		if (not exists $PEF::Log::Config::config{formats}{$params->{format}}) {
			croak "unknown format $params->{format}";
		}
		$self->{formatter} = $PEF::Log::Config::config{formats}{$params->{format}};
	}
	$self;
}

sub append {
	my ($self, $level, $stream, $msg) = @_;
	if ($self->{filter}) {
		$msg = $self->{filter}->transform($level, $stream, clone $msg);
	}
	if ($self->{formatter}) {
		return $self->{formatter}->($level, $stream, $msg);
	}
	$msg;
}

1;
