package TestLog;
use Carp;

sub new {
	bless \(my $a), $_[0];
}

sub transform {
	my ($self, $level, $sublevel, $msg) = @_;
	croak "not a hash message" if 'HASH' ne ref $msg;
	$msg->{level} = $level;
}

1;