use FindBin qw($Bin);
use lib "$Bin/../lib";
use JSON;
use Test::More;
use PEF::Log (streams => [qw(input output subroutine)]);
PEF::Log->init(plain_config => <<CFG);
---
appenders:
  screen:
    format: line-combo
    out: stderr
  string:
    format: line
formats:
  line:
    format: "%m"
    class: pattern
  line-msg:
    format: "%m{level}: %m{message}"
    class: pattern
  line-level:
    format: "%l: %m"
    class: pattern
  line-combo:
    format: "%d [%P][%l.%s][%C{1}::%S(%L)]: %T %m%n"
    stringify: dumpAll
    class: pattern
overs:
  string-level:
    format: line-level
    appender: string
  string-filter-level:
    filter: TestLog
    format: line-msg
    appender: string
routes:
  default:
    debug: string-level
    info: string
    warning: [string-filter-level]
    error: [string, screen]
    critical: [string, screen]
    fatal: [string, screen]
    deadly: [screen] 
CFG
my $out_string;
logappender("string")->set_out(\$out_string);
logit info { "test message" };
is($out_string, "test message", "simple appender");
$out_string = '';
logit debug { "test message" };
is($out_string, "debug: test message", "over appender");
$out_string = '';
logit warning { {message => "test message"} };
is($out_string, "warning: test message", "over appender");
done_testing();
