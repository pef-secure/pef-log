package PEF::Log::Appender::Dump;
use base 'PEF::Log::Appender';
use PEF::Log::Format::Pattern;
use File::Path 'make_path';
use File::Basename;
use Data::Dumper;
use YAML::XS;
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = bless ({}, $class)->reload(\%params);
	$self;
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	my $out = $params->{out} or croak "no output file";
	my $out_formatter = PEF::Log::Format::Pattern->new(format => $out)->formatter();
	my $cut_line = exists ($params->{"cut-line"}) ? $params->{"cut-line"} : "--==< %d >==--%n";
	my $cut_line_formatter = PEF::Log::Format::Pattern->new(format => $cut_line)->formatter();
	$self->{out_formatter}      = $out_formatter;
	$self->{cut_line_formatter} = $cut_line_formatter;
	$self;
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $fname = $self->{out_formatter}->($level, $sublevel, $msg);
	my ($name, $path, $suffix) = fileparse($fname, q|\.[^\.]*|);
	if (!-d $path) {
		make_path $path or croak "can't create path $path: $!";
	}
	open my $fh, ">>", $fname or croak "can't open output file $fname: $!";
	binmode $fh;
	my $cut = $self->{cut_line_formatter}->($level, $sublevel, $msg);
	utf8::encode($cut) if utf8::is_utf8($cut);
	my $line = $self->SUPER::append($level, $sublevel, $msg);
	utf8::encode($line) if utf8::is_utf8($line);
	print $fh $cut . $line;
	close $fh;
}

1;
