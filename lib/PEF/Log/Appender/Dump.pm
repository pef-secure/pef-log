package PEF::Log::Appender::Dump;
use base 'PEF::Log::Appender';
use PEF::Log::Format::Pattern;
use File::Path 'make_path';
use File::Basename;
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params)->reload(\%params);
	$self;
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	my $out = $params->{out} or croak "no output file";
	my $out_formatter = PEF::Log::Format::Pattern->formatter({format => $out});
	my $cut_line = exists ($params->{"cut-line"}) ? $params->{"cut-line"} : "--==< %d >==--%n";
	my $cut_line_formatter = PEF::Log::Format::Pattern->formatter({format => $cut_line});
	$self->{out_formatter}      = $out_formatter;
	$self->{cut_line_formatter} = $cut_line_formatter;
	$self;
}

sub append {
	my ($self, $level, $stream, $msg) = @_;
	my $fname = $self->{out_formatter}->($level, $stream, $msg);
	my ($name, $path, $suffix) = fileparse($fname, q|\.[^\.]*|);
	if (!-d $path) {
		make_path $path or croak "can't create path $path: $!";
	}
	open my $fh, ">>", $fname or croak "can't open output file $fname: $!";
	binmode $fh;
	my $cut = $self->{cut_line_formatter}->($level, $stream, $msg);
	utf8::encode($cut) if utf8::is_utf8($cut);
	my $line = $self->SUPER::append($level, $stream, $msg);
	utf8::encode($line) if utf8::is_utf8($line);
	print $fh $cut . $line;
	close $fh;
}

1;
