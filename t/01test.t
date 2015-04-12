use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More;

use PEF::Log (sublevels => [qw(input output subroutine)]);
PEF::Log->init(plain_config => <<CFG);
---
appenders:
  screen:
    format: line-combo
    out: stderr
  string-debug:
    format: line
    class: string
  string-info:
    format: line
    class: string
  string-warning:
    format: line-level
    class: string
  string-error:
    format: line-level-sublevel
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
  line-level:
    format: "%l: %m"
    stringify: dumpAll
    class: pattern
  line-level-sublevel:
    format: "%l.%s: %m"
    stringify: dumpAll
    class: pattern
  line-combo:
    format: "%d [%P][%l.%s][%C{1}::%S(%L)]: %T %m%n"
    stringify: dumpAll
    class: pattern
routes:
  default:
    debug: string-debug
    info: string-info
    warning: [string-warning]
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
	logappender($_)->set_out(\$string{$_});
}
logit info { "test message" };
ok($string{"string-info"} eq "test message", "test message passed");
$string{"string-info"} = '';
logit info { "second test message" };
ok($string{"string-info"} eq "second test message", "second message passed");
$string{"string-info"} = '';
logit info { {message => "this is message"} };
ok($string{"string-info"} eq '"message":"this is message"', "hash message passed");
logit debug { "unseen" };
ok($string{"string-debug"} eq '', "debug is off for main");
logcache X => "main";
{
	my $ctx = "second level";
	logcontext \$ctx;
	logcache X => $ctx;
	logit debug { "magic!" };
	ok($string{"string-debug"} eq 'magic!', "debug is on");
	$string{"string-debug"} = '';
	ok(logcache("X") eq $ctx, "context cache is $ctx");
}
ok(logcache("X") eq "main", "context cache is main");
logit debug { "unseen" };
ok($string{"string-debug"} eq '', "debug is off for main - 2");
logit warning { "something happened" };
ok($string{"string-warning"} eq 'warning: something happened', "warning");
$string{"string-warning"} = '';
logit error::output { "something bad happened" };
ok($string{"string-error"} eq 'error.output: something bad happened', "error::output");
$string{"string-error"} = '';

sub level_up {
	logit error::output { "something bad happened" };
	ok($string{"string-error"} eq 'error.output: something bad happened', "error::output");
	$string{"string-error"} = '';
}
level_up;
eval {
	logit deadly { "must die here" };
};
ok($@ eq "it's time to die at 01test.t line " . (__LINE__ - 2) . ".\n", "deadly works");
done_testing();
