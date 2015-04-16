package PEF::Log::Stringify::DumpAll;
use Data::Dumper;
use Scalar::Util qw(blessed);
use strict;
use warnings;
our $dumper;

BEGIN {
	$dumper = Data::Dumper->new([]);
	$dumper->Indent(0);
	$dumper->Pair(":");
	$dumper->Useqq(1);
	$dumper->Terse(1);
	$dumper->Deepcopy(1);
	$dumper->Sortkeys(1);
}

sub new {
	bless \(my $a = $_[1]), $_[0];
}

sub stringify {
	my @params = @_[1 .. $#_];
	if (@params & 1 == 0) {
		$dumper->Values([{@params}]);
	} elsif (@params == 1) {
		$dumper->Values([$_[1]]);
	} else {
		$dumper->Values([\@params]);
	}
	my $ret = $dumper->Dump;
	if (not blessed $_[0] or not $$_[0]) {
		if (substr ($ret, 0, 1) eq '{' || substr ($ret, 0, 1) eq '[') {
			substr ($ret, 0,  1, '');
			substr ($ret, -1, 1, '');
		}
	}
	$ret;
}

1;
