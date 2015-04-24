package PEF::Log::Appender::String;

use base 'PEF::Log::Appender';

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params)->reload(\%params);
	my $str = '';
	$self->{out} = \$str;
	$self;
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
}

sub set_out {
	my ($self, $strref) = @_;
	if('SCALAR' ne ref $strref) {
		warn "bad use of PEF::Log::Appender::String::set_out";
		return;
	}
	$$strref //= '';
	$$strref .= ${$self->{out}};
	$self->{out} = $strref;
}

sub out {
	my $self = $_[0];
	${$self->{out}};
}

sub append {
	my ($self, $level, $stream, $msg) = @_;
	my $line = $self->SUPER::append($level, $stream, $msg);
	${$self->{out}} .= $line;
}

1;
