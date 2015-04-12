package PEF::Log::Config;
use strict;
use warnings;
use YAML::XS qw(LoadFile Load);
use Carp;
use Scalar::Util qw(blessed);

our @reload_watchers;
our %config;
our $file_mtime = 0;

sub _reload_appenders {
	my %config_appenders;
	if (exists $config{file}{appenders}) {
		%config_appenders = %{$config{file}{appenders}};
	}
	if (exists $config{text}{appenders}) {
		my @keys = keys %{$config{text}{appenders}};
		@config_appenders{@keys} = values %{$config{text}{appenders}};
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
			my $conf = 'HASH' eq ref ($appc) ? $appc : {};
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
		@config_formats{@keys} = values %{$config{text}{formats}};
	}
	my @actual_formats = keys %{$config{formats}};
	for my $fmt (@actual_formats) {
		delete $config{formats}{$fmt} if !exists $config_formats{$fmt};
	}
	for my $fmt (keys %config_formats) {
		my $fmtpc = $config_formats{$fmt};
		my $conf = 'HASH' eq ref ($fmtpc) ? $fmtpc : {};
		my $name;
		if (%$conf && exists $conf->{class}) {
			$name = $conf->{class};
			eval "require $name";
			if ($@) {
				$name = "PEF::Log::Format::" . ucfirst $name;
				eval "require $name";
			}
		} else {
			$name = "PEF::Log::Format::" . ucfirst $fmt;
			eval "require $name";
		}
		if ($@) {
			carp "loading format $fmt: $@";
			next;
		}
		$config{formats}{$fmt} = "$name"->new(%$conf)->formatter;
	}
}

sub _reload_routes {
	my %config_routes;
	if (exists $config{file}{routes}) {
		%config_routes = %{$config{file}{routes}};
	}
	if (exists $config{text}{routes}) {
		my @keys = keys %{$config{text}{routes}};
		@config_routes{@keys} = values %{$config{text}{routes}};
	}
	$config{routes} = \%config_routes;
}

sub reload {
	shift @_ if $_[0] eq __PACKAGE__;
	my ($params) = @_;
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
	if (exists $params->{plain_config}) {
		my ($cont) = eval { Load $params->{plain_config} };
		croak $@ if $@;
		$config{text} = $cont;
		$reload = 1;
	}
	if ($reload) {
		_reload_formats();
		_reload_appenders();
		_reload_routes();
	}
}

sub init {
	shift @_ if $_[0] eq __PACKAGE__;
	my %params = @_;
	croak "no config" unless exists $params{file} or exists $params{plain_config};
	reload(\%params);
}

1;
