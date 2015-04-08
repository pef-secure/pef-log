package PEF::Log::Appender::Db;

sub new {
	my ($class, %params) = @_;
	bless \%params, $class;
}


1