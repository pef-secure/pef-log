package PEF::Log::Appender::Screen;
use base 'PEF::Log::Appender';
use PerlIO;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params)->reload(\%params);
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	my $out = uc($params->{out} || 'stderr');
	no strict 'refs';
	my $fh = *{$out};
	my $no_need_encode = defined grep {$_ eq 'utf8'} PerlIO::get_layers($fh);
	$self->{need_encode} = !$no_need_encode;
	$self->{out} = $fh;
	$self;
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $line = '' . $self->SUPER::append($level, $sublevel, $msg);
	utf8::encode($line) if $self->{need_encode} and utf8::is_utf8($line);
	my $fh = $self->{out};
	print $fh $line;
}

1;
