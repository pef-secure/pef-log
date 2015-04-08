package PEF::Log::Appender::File;
use base 'PEF::Log::Appender';

sub new {
	my ($class, %params) = @_;
	bless \%params, $class;
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $line = $self->SUPER::append($level, $sublevel, $msg);
}

1;
