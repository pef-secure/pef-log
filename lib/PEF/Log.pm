package PEF::Log;
use strict;
use warnings;
use Time::HiRes qw(time);
use PEF::Log::Config;
use Scalar::Util qw(weaken blessed reftype);
use base 'Exporter';
use feature 'state';

our @EXPORT = qw{
  logit
};

our $start_time;
our $last_log_event;
our $caller_offset;
our @context;
our %stash;

BEGIN {
	$start_time     = time;
	$last_log_event = 0;
	@context        = (\"main");
	$caller_offset  = 0;
}

sub import {
	my ($class, @args) = @_;
	my $sublevels;
	for (my $i = 0 ; $i < @args ; ++$i) {
		if ($args[$i] eq 'sublevels') {
			my (undef, $sublevels) = splice @args, $i, 2;
			--$i;
			$sublevels = [$sublevels] if 'ARRAY' ne ref $sublevels;
		}
	}
	require PEF::Log::Levels;
	if ($sublevels) {
		PEF::Log::Levels->import(sublevels => $sublevels);
	}
	my %imps = map { $_ => undef } @args, @EXPORT;
	$class->export_to_level(1, $class, keys %imps);

}

sub new {
	my ($class, %params) = @_;
	PEF::Log::Config->new(%params);
	bless \my $a, $_[0];
}

sub stash {
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
	_clean_context;
	return ${$context[-1]};
}

sub push_context (\$) {
	_clean_context;
	push @context, $_[0];
	weaken($context[-1]);
}

sub pop_context ($) {
	_clean_context;
	for (my $i = @context - 1 ; $i > 0 ; --$i) {
		if (${$context[$i]} eq $_[0]) {
			splice @context, $i;
			last;
		}
	}
}

sub route {
	my ($level, $sublevel) = @_;
	my $routes = $PEF::Log::Config::config{routes};
	my $context;
	my $subroutine;
	if (exists ($routes->{context}) && 'HASH' eq ref ($routes->{context}) && %{$routes->{context}}) {
		$context = context();
		$context = undef unless exists $routes->{context}{$context};
	}
	if (exists ($routes->{subroutine}) && 'HASH' eq ref ($routes->{subroutine}) && %{$routes->{subroutine}}) {
		my $ssn;
		for (my $stlvl = 1 ; ; ++$stlvl) {
			my @caller = caller ($PEF::Log::caller_offset + $stlvl);
			$subroutine = $caller[3];
			last if not defined $subroutine;
			($ssn = $subroutine) =~ s/.*:://;
			last if $ssn ne '(eval)' and $ssn ne '__ANON__';
		}
		if (defined $subroutine) {
			if (not exists $routes->{subroutine}{$subroutine}) {
				if (exists $routes->{subroutine}{$ssn}) {
					$subroutine = $ssn;
				} else {
					$subroutine = undef;
				}
			}
		}
	}
	my $opts;
	my $apnd      = [];
	my $check_lvl = sub {
		my $lvl = $_[0];
		if (not exists $opts->{$lvl}) {
			if (exists $opts->{default}) {
				$lvl = 'default';
			} else {
				return;
			}
		}
		if (not ref $opts->{$lvl}) {
			if ($opts->{$lvl} eq 'off') {
				$opts = undef;
			} else {
				$apnd = [$opts->{$lvl}];
			}
		} elsif ('ARRAY' eq ref $opts->{$lvl}) {
			$apnd = $opts->{$lvl};
		} else {
			$opts = $opts->{$lvl};
			return 1;
		}
		return;
	};
	my @larr = ($level);
	push @larr, $sublevel if $sublevel;
	my @scd;
	push @scd, $routes->{subroutine}{$subroutine} if $subroutine;
	push @scd, $routes->{context}{$context}       if $context;
	push @scd, $routes->{default}                 if exists $routes->{default};
	for my $ft (@scd) {
		$opts = $ft;
		for my $l (@larr) {
			last if not $check_lvl->($l);
		}
		last if not $opts or @$apnd;
	}
	$apnd;
}

sub logit {
	state $lvl_prefix = "PEF::Log::Levels::";
	for my $msg (@_) {
		my $blt = blessed $msg;
		if (not $blt) {
			$msg = PEF::Log::Levels::warning { {"not blessed message" => $msg} };
			$blt = blessed $msg;
		}
		if (substr ($blt, 0, length $lvl_prefix) ne $lvl_prefix) {
			$msg = PEF::Log::Levels::warning { {"unknown msg level" => $blt, message => $msg} };
			$blt = blessed $msg;
		}
		my ($level, $sublevel) = split /::/, substr ($blt, length $lvl_prefix);
		my $appenders = route($level, $sublevel);
		return if !@$appenders;
		my @mval = $msg->();
		for my $omv (@mval) {
			for my $ap (@$appenders) {
				$ap->append($level, $sublevel, $omv);
			}
		}
	}
}

1;
