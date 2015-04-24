use FindBin qw($Bin);
use lib "$Bin/../lib";
use PEF::Log::ContextStack;

use Test::More;

my $base = PEF::Log::ContextStack->new("main");
is($base->context, "main", "main");
$base->cache("X" => "X-Wing");
is($base->cache("X"), "X-Wing", "main x-wing");
$base->cache("Y" => "Y-Wing");
is($base->cache("Y"), "Y-Wing", "main y-wing");
{
	my $ctx = "second level";
	$base->context(\$ctx);
	$base->cache("X" => "X-Wong");
	is($base->cache("X"), "X-Wong", "$ctx x-wong");
	is($base->cache("Y"), "Y-Wing", "$ctx y-wing");
}
is($base->cache("X"), "X-Wing", "main x-wing is back");
done_testing();
