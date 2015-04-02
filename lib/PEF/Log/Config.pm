package PEF::Log::Config;
use strict;
use warnings;
use YAML::XS qw(LoadFile Load);
use Carp;
use Scalar::Util qw(blessed);
use PEF::Log::Levels ();

our @reload_watchers;
our %config_opts;
our %config;
our $config_instance;
our $file_mtime = 0;

sub instance {
	$config_instance;
}

sub _reload_appenders {
	my %config_appenders;
	if (exists $config{file}{appenders}) {
		%config_appenders = %{$config{file}{appenders}};
	}
	if (exists $config{text}{appenders}) {
		my @keys = keys %{$config{text}{appenders}};
		@config_appenders{@keys} = values %{$config{file}{appenders}};
	}
	my @actual_appenders = keys %{$config{appenders}};
	for my $ap (@actual_appenders) {
		delete $config{appenders}{$ap} if !exists $config_appenders{$ap};
	}
	for my $ap (keys %config_appenders) {
		if (exists ($config{appenders}{$ap})) {
			if ($config{appenders}{$ap}->can("reload")) {
				$config{appenders}{$ap}->reload($config_appenders{$ap});
			}
		} else {
			my $appc = $config_appenders{$ap};
			my $conf;
			if ('HASH' eq ref $appc) {
				$conf = $appc;
			} else {
				$conf = {};
			}
			my $name;
			if (%$conf && exists $conf->{class}) {
				$name = $conf->{class};
			} else {
				$name = "PEF::Log::Appender::" . ucfirst $ap;
			}
			eval "require $name";
			if ($@ and index ("::", $name) == -1) {
				$name = "PEF::Log::Appender::" . ucfirst $name;
				eval "require $name";
			}
			if ($@) {
				carp "loading appender $ap: $@";
				next;
			}
			$config{appenders}{$ap} = "$name"->new(%$conf);
		}
	}
}

sub _reload_formats {
	my %config_formats;
	if (exists $config{file}{formats}) {
		%config_formats = %{$config{file}{formats}};
	}
	if (exists $config{text}{formats}) {
		my @keys = keys %{$config{text}{formats}};
		@config_formats{@keys} = values %{$config{file}{formats}};
	}
	my @actual_formats = keys %{$config{formats}};
	for my $fmt (@actual_formats) {
		delete $config{formats}{$fmt} if !exists $config_formats{$fmt};
	}
	for my $fmt (keys %config_formats) {
		if (exists ($config{formats}{$fmt})) {
			if ($config{formats}{$fmt}->can("reload")) {
				$config{formats}{$fmt}->reload($config_formats{$fmt});
			}
		} else {
			my $fmtpc = $config_formats{$fmt};
			my $conf;
			if ('HASH' eq ref $fmtpc) {
				$conf = $fmtpc;
			} else {
				$conf = {};
			}
			my $name;
			if (%$conf && exists $conf->{class}) {
				$name = $conf->{class};
			} else {
				$name = "PEF::Log::Format::" . ucfirst $fmt;
			}
			eval "require $name";
			if ($@ and index ("::", $name) == -1) {
				$name = "PEF::Log::Format::" . ucfirst $name;
				eval "require $name";
			}
			if ($@) {
				carp "loading format $fmt: $@";
				next;
			}
			$config{formats}{$fmt} = "$name"->new(%$conf);
		}
	}
}

sub reload {
	my ($self, $params);
	$params ||= \%config_opts;
	my $reload = 0;
	if (exists $params->{file}) {
		my @bfs = stat $params->{file};
		if (@bfs && -f $params->{file} && -r $params->{file}) {
			if ($file_mtime != $bfs[9]) {
				my ($conf) = eval { LoadFile $params->{file} };
				croak $@ if $@;
				$file_mtime   = $bfs[9];
				$config{file} = $conf;
				$reload       = 1;
			}
		} else {
			croak "No such file: $params->{file}";
		}
	}
	if (exists $params->{config}) {
		my ($cont) = eval { Load $params->{config} };
		croak $@ if $@;
		$config{text} = $cont;
		$reload = 1;
	}
	if ($reload) {
		_reload_formats();
		_reload_appenders();
	}
}

sub new {
	my ($class, %params) = @_;
	$config_instance = bless {}, $class;
	%config_opts = %params;
	$config_instance->reload;
	delete $config_opts{config};
	$config_instance;
}

1;
