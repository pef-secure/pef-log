package PEF::Log::Appender::File;
use base 'PEF::Log::Appender';
use IO::Handle;
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params)->reload(\%params);
	truncate $self->{fh}, 0 if $params{init};
	$self;
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	my $out = $params->{out} or croak "no output file";
	return $self if exists $self->{fh} and $out eq $self->{out};
	open my $fh, ">>", $out or croak "can't open output file $out: $!";
	binmode $fh;
	$fh->autoflush();
	close $self->{fh} if $self->{fh};
	$self->{fh} = $fh;
	$self;
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $line = $self->SUPER::append($level, $sublevel, $msg);
	utf8::encode($line) if utf8::is_utf8($line);
	my $fh = $self->{fh};
	$fh->print($line);
	$fh->flush();
	$fh->sync();
}

sub final {
	if ($_[0]->{fh}) {
		close $_[0]->{fh};
		undef $_[0]->{fh};
	}
}

sub DESTROY {
	$_[0]->final;
}

1;
