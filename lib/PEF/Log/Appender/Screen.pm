package PEF::Log::Appender::Screen;

sub new {
	my ($class, %params) = @_;
	bless \%params, $class;
}


1