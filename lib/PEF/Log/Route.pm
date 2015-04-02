package PEF::Log::Route;
use strict;
use warnings;
use Carp;
use Scalar::Util qw(blessed);
use PEF::Log::Config;

sub new {
	my ($class, %params) = @_;
	my $self = bless {}, $class;
	$self->reload(\%params);
	$self;
}

1;
