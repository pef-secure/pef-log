package PEF::Log::Levels;
use Scalar::Util qw(blessed);
use base 'Exporter';
use strict;
use warnings;
use feature 'state';

our @EXPORT = qw(
  debug
  info
  warning
  error
  critical
  fatal
  deadly
);

our @streams;

sub set_special {
	my ($msg, $special) = @_;
	state $lvl_prefix = "PEF::Log::Levels";
	my $blt = blessed $msg;
	if (not $blt) {
		$msg = PEF::Log::Levels::warning { {"not blessed message" => $msg} };
		$blt = blessed $msg;
	}
	if (substr ($blt, 0, length $lvl_prefix) ne $lvl_prefix) {
		$msg = PEF::Log::Levels::warning { {"unknown msg level" => $blt, message => $msg} };
		$blt = blessed $msg;
	}
	my ($level, $stream) = split /::/, substr ($blt, 2 + length $lvl_prefix);
	bless $_[0], join "::", $lvl_prefix, $level, $stream, $special;
	$msg;
}

sub make_stream {
	my ($stream) = @_;
	no strict 'refs';
	if (not defined &{"debug::$stream"}) {
		for my $l (@EXPORT) {
			eval <<SL;
	sub ${l}::${stream} (&\@) {
		bless \$_[0], "PEF::Log::Levels::${l}::$stream"; 
		\@_ 
	}
SL
		}

	}
}

sub import {
	my ($class, @args) = @_;
	for (my $i = 0 ; $i < @args ; ++$i) {
		if ($args[$i] eq 'streams') {
			my (undef, $sl) = splice @args, $i, 2;
			--$i;
			$sl = [$sl] if 'ARRAY' ne ref $sl;
			@streams = @$sl;
		}
	}
	if (@streams) {
		state $sldone = 0;
		if (!$sldone) {
			for my $sl (@streams) {
				make_stream($sl);
			}
		}
		$sldone = 1;
	}
	my %imps = map { $_ => undef } @args, @EXPORT;
	$class->export_to_level(2, $class, keys %imps);
}

sub debug (&@)    { bless $_[0], "PEF::Log::Levels::debug";    @_ }
sub info (&@)     { bless $_[0], "PEF::Log::Levels::info";     @_ }
sub warning (&@)  { bless $_[0], "PEF::Log::Levels::warning";  @_ }
sub error (&@)    { bless $_[0], "PEF::Log::Levels::error";    @_ }
sub critical (&@) { bless $_[0], "PEF::Log::Levels::critical"; @_ }
sub fatal (&@)    { bless $_[0], "PEF::Log::Levels::fatal";    @_ }
sub deadly (&@)   { bless $_[0], "PEF::Log::Levels::deadly";   @_ }

1;
