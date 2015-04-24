use FindBin qw($Bin);
use lib "$Bin/../lib";
use JSON;
use Test::More;
use PEF::Log;

logcache X => "X-Wing";
is(logcache("X"), "X-Wing", logcontext . " x-wing");
logcache Y => "Y-Wing";
is(logcache("Y"), "Y-Wing", logcontext . " y-wing");
{
	my $ctx = "second level";
	logcontext \$ctx;
	logcache X => "X-Wong";
	is(logcache("X"), "X-Wong", logcontext . " x-wong");
	logcache Y => "Y-Wing";
	is(logcache("Y"), "Y-Wing", logcontext . " y-wing");
}
is(logcache("X"), "X-Wing", logcontext . " x-wing");
{
	my $stkbind = "new stack";
	logswitchstack \$stkbind;
	is(logcache("Y"), undef, logcontext . " Y");
	logcache X => "X-Ping";
	is(logcache("X"), "X-Ping", logcontext . " x-ping");
	logswitchstack "default";
	is(logcache("X"), "X-Wing", logcontext . " x-wing");
}
{
	my $stkbind = "new stack";
	logswitchstack \$stkbind;
	is(logcache("Y"), undef, logcontext . " Y");
	logcache Y => "Y-Ping";
	is(logcache("Y"), "Y-Ping", logcontext . " y-ping");
	logswitchstack "default";
	is(logcache("X"), "X-Wing", logcontext . " x-wing");
	logswitchstack $stkbind;
	is(logcache("Y"), "Y-Ping", logcontext . " y-ping");
	logswitchstack "default";
	logswitchstack \$stkbind;
	is(logcache("Y"), "Y-Ping", logcontext . " y-ping");
}
is(logcache("Y"), "Y-Wing", logcontext . " y-wing");
done_testing();
