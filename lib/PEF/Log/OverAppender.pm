package PEF::Log::OverAppender;
use base 'PEF::Log::Appender';
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params)->reload(\%params);
	$self;
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	if (not exists ($params->{appender})) {
		croak "need appender for overs";
	}
	if (not exists $PEF::Log::Config::config{appenders}{$params->{appender}}) {
		croak "unknown appender $params->{appender}";
	}
	$self->{appender} = $PEF::Log::Config::config{appenders}{$params->{appender}};
	my $app_sub = <<APS;
	sub {
		my (\$self, \$level, \$stream, \$msg) = \@_;
APS
	if (exists $self->{filter}) {
		$app_sub .= <<APS;
		local \$self->{appender}->{filter} = \$self->{filter};
APS
	}
	if (exists $self->{formatter}) {
		$app_sub .= <<APS;
		local \$self->{appender}->{formatter} = \$self->{formatter};
APS
	}
	$app_sub .= <<APS;
		\$self->{appender}->append(\$level, \$stream, \$msg);
	}
APS
	eval "\$self->{sub} = $app_sub";
	$self;
}

sub append {
	my ($self, $level, $stream, $msg) = @_;
	$self->{sub}->($self, $level, $stream, $msg);
}

1;
