package PEF::Log::Format::Dumper;
use Data::Dumper;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $dumper = Data::Dumper->new([]);
	$dumper->Terse(1)->Deepcopy(1);
	bless {dumper => $dumper}, $class;
}

sub formatter {
	my $self = $_[0];
	return sub {
		my ($level, $sublevel, $message) = @_;
		$message = {message => $message} if not ref $message;
		$self->{dumper}->Values([$message]);
		$self->{dumper}->Dump;
	};
}

1;
