package PEF::Log::Appender::Socket;
use base 'PEF::Log::Appender';
use IO::Socket;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Errno;
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = $class->SUPER::new(%params);
	$self->{owner_pid} = 0;
	$self->reload(\%params);
}

sub reload {
	my ($self, $params) = @_;
	$self->_reload($params);
	my $out = $params->{out} or croak "no output socket";
	$self->_final if $$ != $self->{owner_pid};
	return $self if exists $self->{sock} and $self->{sock} and $out eq $self->{out};
	$self->{out} = $out;
	my ($scheme, $authority, $path, $query, $fragment) =
	  $out =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
	my @socket_params;
	my $socket_class;
	if ($scheme eq 'unix') {
		# unix stream
		@socket_params = (
			Type => SOCK_STREAM,
			Peer => $path
		);
		$socket_class = "IO::Socket::UNIX";
	} elsif ($scheme eq 'local') {
		@socket_params = (
			Type => SOCK_DGRAM,
			Peer => $path
		);
		$socket_class = "IO::Socket::UNIX";
	} elsif ($scheme eq 'tcp') {
		@socket_params = (
			Timeout => $params->{timeout} || 3,
			Type => SOCK_STREAM,
			PeerAddr => $authority,
			Proto    => 'tcp',
		);
		$socket_class = "IO::Socket::INET";
	} elsif ($scheme eq 'local') {
		@socket_params = (
			Timeout => $params->{timeout} || 3,
			Type => SOCK_DGRAM,
			PeerAddr => $authority,
			Proto    => 'udp',
		);
		$socket_class = "IO::Socket::INET";
	} else {
		croak "unknown socket scheme";
	}
	$self->{socket_class}  = $socket_class;
	$self->{socket_params} = \@socket_params;
	$self->_reconnect;
	$self;
}

sub _reconnect {
	my ($self, $params) = @_;
	my $socket_class = $self->{socket_class};
	$self->_final;
	$self->{sock} = "$socket_class"->new(@{$self->{socket_params}})
	  or croak "can't connect to $self->{out}: $!";
	$self->{owner_pid} = $$;
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	my $line = $self->SUPER::append($level, $sublevel, $msg);
	utf8::encode($line) if utf8::is_utf8($line);
	my $attempts = 0;
	my $octets   = length ($line);
	while (1) {
		my $len = length ($line);
		my $rc  = $self->{sock}->syswrite($line);
		if (!defined $rc) {
			if ($!{EINTR} || $!{EAGAIN}) {
				next;
			}
			if (++$attempts > 5) {
				croak "Socket::append ($len): $!";
			}
			$self->_reconnect;
		} else {
			if ($octets != $rc) {
				substr ($line, 0, $rc) = '';
				$octets -= $rc;
			} else {
				last;
			}
		}
	}
}

sub final {
	if ($_[0]->{sock}) {
		close $_[0]->{sock};
		undef $_[0]->{sock};
	}
}

sub DESTROY {
	$_[0]->final;
}

1;
