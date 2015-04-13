package PEF::Log::Appender::Dbi;
use DBIx::Connector;
use base 'PEF::Log::Appender';
use PEF::Log::Format::Pattern;
use PEF::Log::Stringify::DumpAll;
use Scalar::Util qw(blessed);
use Clone 'clone';
use Carp;
use strict;
use warnings;

sub new {
	my ($class, %params) = @_;
	my $self = {%params};
	bless $self, $class;
	$self->reload(\%params);
}

# supported params are:
#   filter -- message filtering class
#   dsn, user, password -- db connection parameters
#   out -- logging table
#   fields -- fields to insert
#   skip-not-exists -- when true all missed fields will be set to undef
#   skip-undef -- when true all undef fields a stripped
#   new-row-func -- inserting functiuon. one of: struct_new_row, connector_new_row, dbi_new_row
#   rest -- where to put rest of the message fields

sub reload {
	my ($self, $params) = @_;
	if (exists ($params->{filter}) && $params->{filter}) {
		eval "use $params->{filter}";
		croak $@ if $@;
		$self->{filter} = "$params->{filter}"->new($params);
	}
	my $log_table = $params->{out} or croak "no log table";
	$self->{log_table} = $log_table;
	if (   exists ($params->{dsn})
		&& $params->{dsn}
		&& (   !exists ($self->{connector})
			|| $params->{dsn} ne $self->{dsn}
			|| $params->{user} ne $self->{user}
			|| $params->{password} ne $self->{password})
	  )
	{
		my $connector = $params->{connector} || "DBIx::Connector";
		eval "use $connector" if $connector ne "DBIx::Connector";
		$self->{connector} = $connector->new(
			$params->{dsn},
			$params->{user},
			$params->{password},
			{   RaiseError          => 1,
				AutoCommit          => 1,
				AutoInactiveDestroy => 1
			}
		);
		$self->{dsn}      = $params->{dsn};
		$self->{user}     = $params->{user};
		$self->{password} = $params->{password};
	}
	my $std_header = '';
	if ($self->{filter}) {
		$std_header .= <<PA
		\$self->{filter}->transform(\$level, \$sublevel, \$msg);
PA
	}
	$std_header .= <<HS;
		\$msg = {message => \$msg} if 'HASH' ne ref \$msg;
HS
	if ($params->{fields}) {
		my $fields = 'ARRAY' eq ref ($params->{fields}) ? $params->{fields} : [$params->{fields}];
		my $kl = join ",", map { PEF::Log::Format::Pattern::_quote_sep($_) . " => undef" }
		  grep { $_ ne '' } map { s/^\s+//; s/\s+$//; $_ } @$fields;
		$std_header .= <<KN
		my \%known_fields = ($kl);
KN
	} else {
		$std_header .= <<KN
		my \%known_fields = ();
KN
	}
	if (exists ($params->{"skip-not-exists"}) && !$params->{"skip-not-exists"}) {
		$std_header .= <<KN
		for my \$k (keys \%known_fields) {
			\$msg->{\$k} = undef if not exists \$msg->{\$k};
		}
KN
	}
	if (exists ($params->{"skip-undef"}) && !$params->{"skip-undef"}) {
		$std_header .= <<KN
		for my \$k (keys \%\$msg) {
			delete \$msg->{\$k} if not defined \$msg->{\$k};
		}
KN
	}
	if ($params->{rest}) {
		$std_header .= <<KN
		my \@rest = grep {not exists \$known_fields{\$_}} keys \%\$msg;
		if(\@rest) {
			my \$srest = PEF::Log::Stringify::DumpAll->stringify({map {\$_ => \$msg->{\$_}} \@rest});
			if(\$msg->{'$params->{rest}'}) {
				\$msg->{'$params->{rest}'} .= "; ";
			}
			\$msg->{'$params->{rest}'} .= \$srest;
			delete \$msg->{\$_} for \@rest;
		}
KN
	} else {
		$std_header .= <<KN
		my \@rest = grep {not exists \$known_fields{\$_}} keys \%\$msg;
		delete \$msg->{\$_} for \@rest;
KN

	}
	$std_header .= <<KN;
		for my \$k (keys \%\$msg) {
			delete \$msg->{\$k} if blessed \$msg->{\$k};
		}
KN
	$self->{parts}{header} = $std_header;
	if ($params->{"new-row-func"}) {
		$self->{"new-row-func"} = $params->{"new-row-func"};
	} else {
		delete $self->{"new-row-func"};
	}
	$self;
}

sub connector_new_row {
	my ($conn, $log_table, %params) = @_;
	$conn->run(
		sub {
			$_->do(
				qq{insert into $log_table(}
				  . join (",", keys %params)
				  . qq{) values (}
				  . (join ",", ('?') x scalar keys %params) . qq{)},
				undef,
				values %params
			);
		}
	);
}

sub dbi_new_row {
	my ($conn, $log_table, %params) = @_;
	$conn->do(
		qq{insert into $log_table(}
		  . join (",", keys %params)
		  . qq{) values (}
		  . (join ",", ('?') x scalar keys %params) . qq{)},
		undef,
		values %params
	);
}

sub struct_new_row {
	my ($conn, $log_table, %params) = @_;
	DBIx::Struct::new_row($log_table, %params);
}

sub connector {
	my ($self, $connector) = @_;
	return $self->{connector} if @_ == 1;
	my $newrow;
	$self->{connector} = $connector;
	if ($connector->isa("DBIx::Connector")) {
		if ($connector->isa("DBIx::Struct::Connector")) {
			$newrow = "struct_new_row";
		} else {
			$newrow = "connector_new_row";
		}
	} else {
		$newrow = "dbi_new_row";
	}
	if ($self->{"new-row-func"} && $self->can($self->{"new-row-func"})) {
		$newrow = $self->{"new-row-func"};
	}
	$self->{parts}{newrow} = <<NR;
		$newrow(\$self->{connector}, '$self->{log_table}', \%\$msg) if \%\$msg;
NR
}

sub append {
	my ($self, $level, $sublevel, $msg) = @_;
	$msg = clone $msg;
	if (!$self->{parts}{newrow}) {
		$self->connector($self->{connector});
	}
	if (!$self->{append}) {
		my $sub = <<APP;
		sub {
			my (\$self, \$level, \$sublevel, \$msg) = \@_;
			$self->{parts}{header}
			$self->{parts}{newrow}
		}
APP
		$self->{append} = eval $sub;
		warn $@ if $@;
	}
	$self->{append}->($self, $level, $sublevel, $msg);
}

1;
