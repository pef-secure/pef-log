package PEF::Log::ContextStack;
use Scalar::Util qw(weaken);
use Carp;
use strict;
use warnings;

sub ctxstack () { 0 }
sub ctxstore () { 1 }

sub new {
	my ($class, $main_context) = @_;
	$main_context //= 'main';
	bless [[\$main_context], [{}]], $class;
}

sub _clean_context {
	my $self     = $_[0];
	my $ctxstack = $self->[ctxstack];
	pop @$ctxstack while @$ctxstack and not defined $ctxstack->[-1];
	splice @{$self->[ctxstore]}, scalar @$ctxstack;
}

sub cache {
	$_[0]->_clean_context;
	my $cache = $_[0][ctxstore][-1];
	if (@_ == 2) {
		return $cache->{$_[1]} if exists $cache->{$_[1]};
		for (my $i = $#{$_[0][ctxstore]} - 1 ; $i > -1 ; --$i) {
			$cache = $_[0][ctxstore][$i];
			return $cache->{$_[1]} if exists $cache->{$_[1]};
		}
		return;
	} elsif (@_ == 1) {
		$cache;
	} else {
		$cache->{$_[1]} = $_[2];
	}
}

sub context {
	$_[0]->_clean_context;
	if (@_ > 1) {
		carp "not scalar reference" if 'SCALAR' ne ref $_[1];
		my $ctxstack = $_[0][ctxstack];
		push @$ctxstack, $_[1];
		weaken($ctxstack->[-1]);
		push @{$_[0][ctxstore]}, {};
		return ${$ctxstack->[-1]} if defined wantarray;
	} else {
		${$_[0][ctxstack][-1]};
	}
}

sub pop {
	$_[0]->_clean_context;
	my $waterline = $_[1] // ${$_[0][ctxstack][-1]};
	for (my $i = $#{$_[0][ctxstack]} ; $i > 0 ; --$i) {
		if (${$_[0][ctxstack][$i]} eq $_[1]) {
			splice @{$_[0][ctxstack]}, $i;
			splice @{$_[0][ctxstore]}, $i;
			last;
		}
	}
}

1;
