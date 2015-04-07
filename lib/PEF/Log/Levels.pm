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

our %_to_int = (
	debug    => 5,
	info     => 4,
	warning  => 3,
	warn     => 3,
	error    => 2,
	critical => 1,
	fatal    => 1,
	deadly   => 0
);

our @_to_name = qw(deadly critical error warning info debug);

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
					my $il = $_to_int{$l};
					eval <<SL;
	sub ${l}::${sl} (&\@) {
		bless \$_[0], "PEF::Log::Levels::${il}::$sl"; 
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

sub debug (&@)    { bless $_[0], "PEF::Log::Levels::5"; @_ }
sub info (&@)     { bless $_[0], "PEF::Log::Levels::4"; @_ }
sub warning (&@)  { bless $_[0], "PEF::Log::Levels::3"; @_ }
sub error (&@)    { bless $_[0], "PEF::Log::Levels::2"; @_ }
sub critical (&@) { bless $_[0], "PEF::Log::Levels::1"; @_ }
sub fatal (&@)    { bless $_[0], "PEF::Log::Levels::1"; @_ }
sub deadly (&@)   { bless $_[0], "PEF::Log::Levels::0"; @_ }

1;