package TestLog;
use Carp;

sub new {
	bless \(my $a), $_[0];
}

sub transform {
	my ($self, $level, $stream, $msg) = @_;
	if ('HASH' eq ref $msg) {
		$msg->{level} = $level;
	}
	$msg if defined wantarray;
}

1;
