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

our @sublevels;

sub import {
	my ($class, @args) = @_;
	for (my $i = 0 ; $i < @args ; ++$i) {
		if ($args[$i] eq 'sublevels') {
			my (undef, $sl) = splice @args, $i, 2;
			--$i;
			$sl = [$sl] if 'ARRAY' ne ref $sl;
			@sublevels = @$sl;
		}
	}
	if (@sublevels) {
		state $sldone = 0;
		if (!$sldone) {
			for my $sl (@sublevels) {
				for my $l (@EXPORT) {
					eval <<SL;
	sub ${l}::${sl} (&\@) {
		bless \$_[0], "PEF::Log::Levels::${l}::$sl"; 
		\@_ 
	}
SL
				}
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
