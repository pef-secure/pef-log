package PEF::Log::Format::Dumper;
use Data::Dumper;
use strict;
use warnings;

sub formatter {
	my $dumper = Data::Dumper->new([]);
	$dumper->Terse(1)->Deepcopy(1);
	return sub {
		my ($level, $sublevel, $message) = @_;
		$message = {message => $message} if not ref $message;
		$dumper->Values([$message]);
		$dumper->Dump;
	};
}

1;
