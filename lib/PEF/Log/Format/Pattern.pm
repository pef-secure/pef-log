package PEF::Log::Format::Pattern;
use POSIX qw(strftime);
use Data::Dumper;
use Time::HiRes qw(time);
use Carp;

use strict;
use warnings;

sub _quote_sep {
	my $s = $_[0];
	my $d = Data::Dumper->new([$s]);
	$d->Indent(0);
	$d->Terse(1);
	my $qs = $d->Dump;
	$qs = "'$qs'" if substr ($qs, 0, 1) ne "'";
	return $qs;
}

#    %d Current date in %y.%m.%d %H:%M:%S format
#    %d{...} Current date in customized format
#    %l Level of the message to be logged
#    %s Sublevel of the message to be logged
#    %n New line
#    %m Stringified message to be logged
#    %m{} Key value(s) of message to be logged
#    %M{} Excluded key value(s) of message to be logged
#    %L Line number within the file where the log statement was issued
#    %C{} Module/Class name or its part from end where the logging request was issued
#    %S subroutine where the logging request was issued
#    %P pid of the current process
#    %r Number of milliseconds elapsed from program start to logging
#       event
#    %R Number of milliseconds elapsed from last logging event to
#       current logging event
#    %T A stack trace of functions called
#    %x The topmost context name
#    %c{} Value of the key from context cache
#    %G{} Value of the key from global store
#    %% A literal percent (%) sign

sub new {
	my ($class, %params) = @_;
	my $stringify = $params{stringify} || "PEF::Log::Stringify::DumpAll";
	eval "require $stringify";
	if ($@) {
		$stringify = "PEF::Log::Stringify::" . ucfirst ($stringify);
		eval "require $stringify";
	}
	croak "error loading stringify module: $stringify" if $@;
	my $format = $params{format} || "%d %m%n";
	bless {stringify => $stringify, format => $format}, $_[0];
}

sub build_formatter {
	my $self       = $_[0];
	my $format     = $self->{format};
	my $stringify  = $self->{stringify};
	my %info_parts = (
		d => sub {
			my ($params) = @_;
			my $fmt = $params || "%y.%m.%d %H:%M:%S";
			"d$params" => <<IP
			\$info{"d$params"} = strftime("$fmt", localtime);
IP
		},
		l => sub {
			my ($params) = @_;
			l => <<IP
			\$info{l} = \$level;
IP
		},
		s => sub {
			my ($params) = @_;
			s => <<IP
			\$info{s} = \$sublevel || '';
IP
		},
		n => sub {
			my ($params) = @_;
			n => <<IP
			\$info{n} = "\\n";
IP
		},
		m => sub {
			my ($params) = @_;
			my $sep = "' '";
			if ($params ne '') {
				my $ss = sub { $sep = _quote_sep $_[0]; '' };
				(my $cp = $params) =~ s/-sep\s*=>?\s*("?)([^"]*)\1/$ss->($2)/e;
				my @keys = grep { $_ ne '' } map { s/^\s+//; s/\s+$//; $_ } split ',', $params;
				my $kl = join ",", map { _quote_sep $_} @keys;
				my $hashmsg;
				if (@keys == 0) {
					$hashmsg = "$stringify->stringify(\$message)";
				} elsif (@keys == 1) {
					$hashmsg = "ref(\$message->{$kl})? $stringify->stringify(\$message->{$kl}): \$message->{$kl}";
				} else {
					$hashmsg = "$stringify->stringify({map { \$_ => \$message->{\$_}} ($kl)})";
				}
				"m$params" => <<IP
				if('HASH' eq ref \$message) {
					\$info{"m$params"} = $hashmsg;
				} elsif('ARRAY' eq ref \$message) {
					\$info{"m$params"} = join($sep, \@\$message);
				} else {
					\$info{"m$params"} = \$message;
				}
IP
			} else {
				m => <<IP
				if('HASH' eq ref \$message) {
					\$info{m} = $stringify->stringify(\$message);
				} elsif('ARRAY' eq ref \$message) {
					\$info{m} = join($sep, \@\$message);
				} else {
					\$info{m} = \$message;
				}
IP
			}
		},
		M => sub {
			my ($params) = @_;
			my $sep = "' '";
			if ($params ne '') {
				my $ss = sub { $sep = _quote_sep $_[0]; '' };
				(my $cp = $params) =~ s/-sep\s*=>?\s*("?)([^"]*)\1/$ss->($2)/e;
				my $kl = join ",",
				  map { _quote_sep($_) . " => undef" } grep { $_ ne '' } map { s/^\s+//; s/\s+$//; $_ } split ',',
				  $params;
				"M$params" => <<IP
				if('HASH' eq ref \$message) {
					my \%known = ($kl);
					my \@unknown = grep {not exists \$message->{\$_}} keys \%\$message;
					\$info{"M$params"} = $stringify->stringify({map { \$_ => \$message->{\$_}} \@unknown});
				} else {
					\$info{"M$params"} = '';
				}
IP
			} else {
				M => <<IP
				\$info{M} = '';
IP
			}
		},
		caller => sub {
			<<CALLER
			my (\$package, undef, \$line) = caller(\$PEF::Log::caller_offset + 3);
			\$info{L} = \$line // '[undef]';
			\$info{C} = \$package // 'main';
CALLER
		},
		T => sub {
			T => <<IP
			{
				require Carp;
				local \$Carp::CarpLevel = \$Carp::CarpLevel + \$PEF::Log::caller_offset + 3;
				my \$mess = Carp::longmess(); 
				chomp(\$mess);
				\$mess =~ s/(?:\\A\\s*at.*\\n|^\\s*)//mg;
				\$mess =~ s/\\n/, /g;
				\$info{T} = \$mess;
			}
IP
		},
		L => sub {
			my ($params) = @_;
			L => '';
		},
		C => sub {
			my ($params) = @_;
			if ($params) {
				my $num = 0 + $params;
				"C$params" => <<IP
				my \@cp = split /::/, \$info{"C"};
				if(\@cp > $num) {
					splice \@cp, 0, \@cp - $num;
				}
				\$info{"C$params"} = join "::", \@cp;
IP
			} else {
				C => '';
			}
		},
		S => sub {
			my ($params) = @_;
			S => <<IP
			my \$subroutine;
			for(my \$stlvl = 4;;++\$stlvl) {
				my \@caller = caller(\$PEF::Log::caller_offset + \$stlvl);
				\$subroutine = \$caller[3];
				last if not defined \$subroutine;
				\$subroutine =~ s/.*:://;
				last if \$subroutine ne '(eval)' and \$subroutine ne '__ANON__'; 
			}
			\$info{S} = \$subroutine // '/unknown/';
IP
		},
		P => sub {
			my ($params) = @_;
			P => <<IP
			\$info{P} = \$\$;
IP
		},
		r => sub {
			my ($params) = @_;
			r => <<IP
			\$info{r} = sprintf("%.3f ms", 1000 * (time - \$PEF::Log::start_time));
IP
		},
		R => sub {
			my ($params) = @_;
			R => <<IP
			\$info{R} = sprintf("%.3f ms", 1000 * (time - \$PEF::Log::last_log_event));
IP
		},
		x => sub {
			my ($params) = @_;
			x => <<IP
			\$info{x} = PEF::Log::context;
IP
		},
		c => sub {
			my ($params) = @_;
			my @keys = grep { $_ ne '' } map { s/^\s+//; s/\s+$//; $_ } split ',', $params;
			my $kl = join ",", map { _quote_sep $_} @keys;
			my $hashmsg;
			if (@keys == 0) {
				$hashmsg = "$stringify->stringify(PEF::Log::logcache())";
			} elsif (@keys == 1) {
				$hashmsg =
				  "ref(PEF::Log::logcache($kl))? $stringify->stringify(PEF::Log::logcache($kl)): PEF::Log::logcache($kl)";
			} else {
				$hashmsg = "$stringify->stringify({map { \$_ => PEF::Log::logcache(\$_)} ($kl)})";
			}
			"c$params" => <<IP
			\$info{"c$params"} = $hashmsg;
IP
		},
		G => sub {
			my ($params) = @_;
			return () if $params eq '';
			my $sep = " ";
			my $ss = sub { $sep = _quote_sep $_[0]; '' };
			(my $cp = $params) =~ s/-sep\s*=>?\s*("?)([^"]*)\1/$ss->($2)/e;
			my @keys = grep { $_ ne '' } map { s/^\s+//; s/\s+$//; $_ } split ',', $params;
			my $kl = join ",", map { _quote_sep $_} @keys;
			my $hashmsg;
			if (@keys == 0) {
				$hashmsg = "$stringify->stringify(PEF::Log::logstore())";
			} elsif (@keys == 1) {
				$hashmsg =
				  "ref(PEF::Log::logstore($kl))? $stringify->stringify(PEF::Log::logstore($kl)): PEF::Log::logstore($kl)";
			} else {
				$hashmsg = "$stringify->stringify({map { \$_ => PEF::Log::logstore(\$_)} ($kl)})";
			}
			"G$params" => <<IP
			\$info{"G$params"} = $hashmsg;
IP
		},
	);
	my %need_info;
	my @need_ops;
	my $bfs = sub {
		my ($len, $data, $params) = @_;
		$need_info{caller} = $info_parts{caller}->() if grep { $_ eq $data } qw(L C);
		if (my ($info, $code) = $info_parts{$data}->($params)) {
			$need_info{$info} = $code;
			push @need_ops, "\$info{" . _quote_sep($info) . "}";
			return "%${len}s";
		} else {
			return '';
		}
	};
	$format =~ s/%(-?\d*(?:\.\d+)?) 
                  ([dlsnmMLCSPrRTxcG%])
                  (?:\{(.*?)\})*/
                  $bfs->($1||'', $2, $3||'')
                /gex;
	my $sprf = _quote_sep $format;
	my $code = '';
	if (exists $need_info{caller}) {
		$code .= $need_info{caller};
		delete $need_info{caller};
	}
	for my $info (keys %need_info) {
		$code .= $need_info{$info};
	}
	my $spra = join ",", @need_ops;
	my $formatter = <<FMT;
	sub {
		my (\$level, \$sublevel, \$message) = \@_;
		my \%info;
		$code
		sprintf $sprf, $spra;
	}
FMT
}

sub formatter {
	my $self = $_[0];
	eval $self->build_formatter;
}

1;
