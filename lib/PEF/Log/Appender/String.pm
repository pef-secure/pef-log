package PEF::Log::Appender::String;

use base 'PEF::Log::Appender';

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params);
	$self->{out} = \(my $str = '');
	$self;
}

sub set_out {
	my ($self, $strref) = @_;
	$$strref //= '';
	$$strref .= ${$self->{out}};
	$self->{out} = $strref;
}

sub out {
	my $self = $_[0];
	${$self->{out}};
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $line = $self->SUPER::append($level, $sublevel, $msg);
	${$self->{out}} .= $line;
}

1;
