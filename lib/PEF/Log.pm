package PEF::Log;
use strict;
use warnings;
use Carp;
use Time::HiRes qw(time);
use PEF::Log::Config;
use PEF::Log::Levels ();
use PEF::Log::ContextStack;
use Scalar::Util qw(weaken blessed reftype isweak);
use base 'Exporter';
use feature 'state';

our $VERSION = '0.01';

our @EXPORT = qw{
  logappender
  logcache
  logcontext
  logit
  logstore
  logswitchstack
};

our $start_time;
our $last_log_event;
our $caller_offset;
our %context_map;
our %stash;
our $current_stack;
our $current_stack_nwr;
our $main_context_name;
our $routes_default_name;
our @error_queue;

BEGIN {
	$start_time          = time;
	$last_log_event      = 0;
	$main_context_name   = "main";
	$current_stack_nwr   = \$main_context_name;
	%context_map         = (default => [\$main_context_name, PEF::Log::ContextStack->new($main_context_name)]);
	$current_stack       = $context_map{default}[1];
	$caller_offset       = 0;
	$routes_default_name = 'default';
}

sub import {
	my ($class, @args) = @_;
	my ($sln, $streams);
	my @config;
	for (my $i = 0 ; $i < @args ; ++$i) {
		if ($args[$i] eq 'streams') {
			($sln, $streams) = splice @args, $i, 2;
			--$i;
			$streams = [$streams] if 'ARRAY' ne ref $streams;
		} elsif ($args[$i] eq 'main_context') {
			my (undef, $main_context_name) = splice @args, $i, 2;
			--$i;
			$context_map{default}[1] = PEF::Log::ContextStack->new($main_context_name);
			$current_stack = $context_map{default}[1];
		} elsif ($args[$i] eq 'file'
			|| $args[$i] eq 'config'
			|| $args[$i] eq 'plain_config'
			|| $args[$i] =~ /^reload/)
		{
			push @config, splice @args, $i, 2;
			--$i;
		} elsif ($args[$i] eq 'routes_default') {
			my (undef, $rdf) = splice @args, $i, 2;
			--$i;
			$routes_default_name = $rdf;
		}
	}
	if (@config) {
		PEF::Log::Config::init(@config);
	}
	if ($sln) {
		PEF::Log::Levels->import($sln, $streams);
	} else {
		PEF::Log::Levels->import();
	}
	$class->export_to_level(1, $class, @EXPORT);
}

sub init {
	shift @_ if $_[0] eq __PACKAGE__;
	PEF::Log::Config::init(@_);
}

sub reload {
	shift @_ if $_[0] eq __PACKAGE__;
	local $@;
	PEF::Log::Config::reload(@_);
}

sub logappender ($) {
	my $ap = $_[0];
	return if not exists $PEF::Log::Config::config{appenders}{$ap};
	$PEF::Log::Config::config{appenders}{$ap};
}

sub logstore {
	if (@_ == 1) {
		$stash{$_[0]};
	} elsif (@_ == 0) {
		\%stash;
	} else {
		$stash{$_[0]} = $_[1];
	}
}

sub logcache {
	if (not defined $current_stack_nwr) {
		$current_stack_nwr = $context_map{default}[0];
		$current_stack     = $context_map{default}[1];
	}
	$current_stack->cache(@_);
}

sub logcontext {
	if (not defined $current_stack_nwr) {
		$current_stack_nwr = $context_map{default}[0];
		$current_stack     = $context_map{default}[1];
	}
	$current_stack->context(@_);
}

sub popcontext ($) {
	if (not defined $current_stack_nwr) {
		$current_stack_nwr = $context_map{default}[0];
		$current_stack     = $context_map{default}[1];
	}
	$current_stack->pop(@_);
}

sub logswitchstack {
	return if not @_;
	if (@_ == 2 and not defined $_[1]) {
		my $csn = (ref $_[0]) ? ${$_[0]} : $_[0];
		if ($$current_stack_nwr eq $csn) {
			$current_stack_nwr = $context_map{default}[0];
			$current_stack     = $context_map{default}[1];
		}
		delete $context_map{$csn};
		return;
	}
	my $defctx = $_[1] // $main_context_name;
	if (ref $_[0]) {
		if ('SCALAR' eq ref $_[0]) {
			if (not exists $context_map{${$_[0]}} or not defined $context_map{${$_[0]}}[0]) {
				$context_map{${$_[0]}} = [$_[0], PEF::Log::ContextStack->new($defctx)];
				my ($key, $value);
				while (($key, $value) = each %context_map) {
					delete $context_map{$key} if not defined $value->[0];
				}
			} else {
				$context_map{${$_[0]}}[0] = $_[0];
			}
			weaken $context_map{${$_[0]}}[0];
			$current_stack_nwr = $_[0];
			weaken $current_stack_nwr;
			$current_stack = $context_map{${$_[0]}}[1];
		} else {
			carp "unknown bind variable type: " . ref $_[0];
		}
	} else {
		unless (exists ($context_map{$_[0]}) && defined $context_map{$_[0]}[0]) {
			$context_map{$_[0]} = [\$_[0], PEF::Log::ContextStack->new($defctx)];
		}
		$current_stack_nwr = $context_map{$_[0]}[0];
		$current_stack     = $context_map{$_[0]}[1];
	}
}

sub logit {
	state $lvl_prefix = "PEF::Log::Levels::";
	my $log_count = 0;
	for (my $imsg = 0 ; $imsg < @_ ; ++$imsg) {
		local $@;
		unshift @_, @error_queue;
		@error_queue = ();
		my $msg = $_[$imsg];
		my $blt = blessed $msg;
		if (not $blt) {
			$msg = PEF::Log::Levels::warning { {"not blessed message" => $msg} };
			$blt = blessed $msg;
		}
		if (substr ($blt, 0, length $lvl_prefix) ne $lvl_prefix) {
			$msg = PEF::Log::Levels::warning { {"unknown msg level" => $blt, message => $msg} };
			$blt = blessed $msg;
		}
		my ($level, $stream, $special) = split /::/, substr ($blt, length $lvl_prefix);
		my %spc_flags;
		%spc_flags = map { $_ => undef } split /:/, $special if $special;
		my $appenders = _route($level, $stream);
		return if !@$appenders;
		my @mval;
		my $got_messages = 0;
		for my $ap (@$appenders) {
			if (not exists $PEF::Log::Config::config{appenders}{$ap}) {
				push @error_queue, PEF::Log::Levels::set_special(
					(
						PEF::Log::Levels::error {
							{   message  => "unknown appender",
								appender => $ap
							}
						}
					),
					"once"
				);
			} else {
				if (!$got_messages) {
					++$log_count;
					$got_messages = 1;
					@mval         = $msg->();
				}
				for my $omv (@mval) {
					eval { $PEF::Log::Config::config{appenders}{$ap}->append($level, $stream, $omv); };
					if ($@ and not exists $spc_flags{once}) {
						if (ref $@ or $@ !~ /^suppress/) {
							push @error_queue, PEF::Log::Levels::set_special(
								(
									PEF::Log::Levels::error {
										{   exception => $@,
											appender  => $ap
										}
									}
								),
								"once"
							);
						}
					}
				}
			}
		}
		$last_log_event = time if $got_messages;
		if ($level eq 'deadly') {
			my @all_appenders = keys %{$PEF::Log::Config::config{appenders}};
			for my $ap (@all_appenders) {
				my $apnd = logappender($ap);
				if ($apnd->can("final")) {
					$apnd->final;
				}
				delete $PEF::Log::Config::config{appenders}{$ap};
			}
			croak "it's time to die";
		}
	}
	$log_count;
}

sub _route {
	my ($level, $stream) = @_;
	my $routes = $PEF::Log::Config::config{routes};
	my $context;
	my $subroutine;
	my @scd;
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
		push @scd, $routes->{subroutine}{$subroutine} if $subroutine;
	}
	if (exists ($routes->{context}) && 'HASH' eq ref ($routes->{context}) && %{$routes->{context}}) {
		$context = logcontext();
		$context = undef unless exists $routes->{context}{$context};
		push @scd, $routes->{context}{$context} if $context;
	}
	if (exists ($routes->{package}) && 'HASH' eq ref ($routes->{package}) && %{$routes->{package}}) {
		my $package = caller (1);
		if (not exists $routes->{package}{$package}) {
			$package = undef;
		}
		push @scd, $routes->{package}{$package} if $package;
	}
	push @scd, $routes->{$routes_default_name} if exists $routes->{$routes_default_name};
	my $apnd = [];
	my $lvlsub;
	my $dotsub;
	if ($stream) {
		$lvlsub = "$level.$stream";
		$dotsub = ".$stream";
	}
	my $apnd_check = sub {
		if (not ref $apnd) {
			if (!defined ($apnd) || $apnd eq 'off' || $apnd eq '') {
				$apnd = [];
			} else {
				$apnd = [$apnd];
			}
		}
	};
	for my $opts (@scd) {
		if ($stream) {
			if (exists $opts->{$lvlsub}) {
				$apnd = $opts->{$lvlsub};
				$apnd_check->();
				last;
			} elsif (exists $opts->{$dotsub}) {
				$apnd = $opts->{$dotsub};
				$apnd_check->();
				last;
			}
		}
		if (exists $opts->{$level}) {
			$apnd = $opts->{$level};
			$apnd_check->();
			last;
		}
	}
	$apnd;
}

1;
