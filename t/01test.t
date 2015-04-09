use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;

use PEF::Log (sublevels => [qw(input output sub)]);
PEF::Log->new(plain_config => <<CFG);
---
appenders:
  screen:
    format: line
    out: stdout
  string-debug:
    format: line
    class: string
  string-info:
    format: line
    class: string
  string-warning:
    format: line
    class: string
  string-error:
    format: line
    class: string
  string-critical:
    format: line
    class: string
  string-fatal:
    format: line
    class: string
formats:
  line:
    format: "%m"
    stringify: dumpAll
    class: pattern
routes:
  default:
    debug: string-debug
    info: string-info
    warning: [string-info]
    error: [string-error, screen]
    critical: [string-critical, screen]
    fatal: [string-fatal, screen]
    deadly: screen
  context:
    main:
      debug: off
    context1:
      info: off
CFG
my %string =
  map { $_ => '' } qw(string-debug string-info string-warning string-error string-critical string-fatal);

for (keys %string) {
	PEF::Log::get_appender($_)->set_out(\$string{$_});
}
logit info { "test message" };
ok($string{"string-info"} eq "test message", "test message passed");
done_testing();
