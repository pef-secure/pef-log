package PEF::Log;
use strict;
use warnings;
use Time::HiRes qw(time);
use PEF::Log::Levels;
use PEF::Log::Config;
use Scalar::Util qw(weaken);
use base 'Exporter';

our @EXPORT = qw {
	logit
};

our $start_time;
our $last_log_event;
our $caller_offset = 0;
our @context = (\"main");
our %stash;

BEGIN {
	$start_time     = time;
	$last_log_event = 0;
}

sub stash {
	shift @_ if $_[0] eq "PEF::Log";
	if (@_ == 1) {
		$stash{$_[0]};
	} elsif (@_ == 0) {
		\%stash;
	} else {
		$stash{$_[0]} = $_[1];
	}
}

sub _clean_context {
	pop @context while @context and not defined $context[-1];
}

sub context {
	shift @_ if $_[0] eq "PEF::Log";
	_clean_context;
	return ${$context[-1]};
}

sub push_context (\$) {
	_clean_context;
	push @context, \$_[0];
	weaken($context[-1]);
}

sub pop_context ($) {
	_clean_context;
	for (my $i = @context-1; $i > 0; -- $i) {
		if(${$context[$i]} eq $_[0]) {
			splice @context, $i;
			last;
		}
	}
}

sub logit {
	
}

1;
