package PEF::Log::Route;
use strict;
use warnings;
use Carp;
use Scalar::Util qw(blessed);
use PEF::Log::Config;

sub reload {
	my ($self, $params) = @_;
	
}

sub new {
	my ($class, %params) = @_;
	my $self = bless {}, $class;
	$self->reload(\%params);
	$self;
}

1;
