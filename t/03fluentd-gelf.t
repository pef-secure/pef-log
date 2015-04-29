use FindBin qw($Bin);
use lib "$Bin/../lib";
use JSON;
use Test::More;
use PEF::Log;
use strict;
use warnings;

PEF::Log->init(plain_config => <<CFG);
---
appenders:
  string-debug:
    format: fluentd
    class: string
  string-info:
    format: fluentdJ
    class: string
  string-warning:
    format: gelf
    class: string
  string-error:
    format: fluentd
    class: string
  string-critical:
    format: fluentdJ
    class: string
  string-fatal:
    format: gelf
    class: string
formats:
  fluentd:
    class: fluentdJ
    tag: "%G{application}"
    container: gelf
  fluentdJ:
    tag: "%l"
    format: "%m"
  gelf:
    short: "%.4m{message}"
    full: "%m"
    host: test
    extra:
      user: "%c{user}"
routes:
  default:
    debug: string-debug
    info: string-info
    warning: [string-warning]
    error: [string-error, screen]
    critical: [string-critical, screen]
    fatal: [string-fatal, screen]
    deadly: off 
CFG
my %string =
  map { $_ => '' } qw(string-debug string-info string-warning string-error string-critical string-fatal);

for (keys %string) {
	logappender($_)->set_out(\$string{$_});
}

logcache user        => "test user";
logstore application => "test-application";

logit info { "test message" };
my $flm = decode_json $string{"string-info"};
ok( $flm->[0] eq "info"
	  && $flm->[1] =~ /^\d+\.\d+$/
	  && $flm->[2]{message} eq 'test message'
	  && $flm->[2]{level} eq 'info',
	'fluentd - simple message'
);
$string{"string-info"} = '';
logit debug { {user => "molly", parent => "holly", message => "your guess"} };
my $flc = decode_json $string{"string-debug"};
ok( $flc->[0] eq 'test-application'
	  && $flc->[1] =~ /^\d+\.\d+$/
	  && $flc->[2]{level} == 7
	  && $flc->[2]{_user} eq logcache("user")
	  && $flc->[2]{timestamp} =~ /^\d+\.\d+$/
	  && $flc->[2]{version} eq '1.1'
	  && $flc->[2]{full_message} eq "\"message\":\"your guess\",\"parent\":\"holly\",\"user\":\"molly\""
	  && $flc->[2]{short_message} eq "your"
	  && $flc->[2]{host} eq "test",
	'fluentd - complex message'
);

done_testing();
