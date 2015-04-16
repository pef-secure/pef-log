use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../../dbix-struct/lib";
use lib "$Bin";
use DBIx::Struct qw(connector);
use Test::More;

#=> \d test_log
#                          Table "public.test_log"
# Column  |  Type   |                       Modifiers
#---------+---------+-------------------------------------------------------
# id      | integer | not null default nextval('test_log_id_seq'::regclass)
# level   | text    |
# action  | text    |
# result  | text    |
# comment | text    |
#Indexes:
#    "test_log_pkey" PRIMARY KEY, btree (id)

use PEF::Log;
PEF::Log->init(plain_config => <<CFG);
---
appenders:
  dbi-system:
    class: dbi
    out: test_log
    filter: TestLog
    fields: [level, action, result, comment]
    skip-not-exists: true
    skip-undef: true
    rest: comment
routes:
  default:
    debug: dbi-system
    info: dbi-system
    warning: dbi-system
    error: dbi-system
    critical: dbi-system
    fatal: dbi-system
    deadly: dbi-system
CFG

my $dbuser = ((getpwuid $>)[0]);
my $dbname = $dbuser;
my $dbpass = "";

DBIx::Struct::connect($dbname, $dbuser, $dbpass) or die;
logappender("dbi-system")->connector(connector);

logit debug { {action => "works", result => "OK", comment => "o'rly?", affirm => "yes!"} };
my $last_log = one_row("test_log", -order_by => {-desc => "id"});
ok( $last_log->action eq 'works'
	  && $last_log->result eq 'OK'
	  && $last_log->level eq 'debug'
	  && $last_log->comment eq q{o'rly?; "affirm":"yes!"},
	'first dbi test'
);
logit debug { {action => "works further", result => "OK", comment => "ohhh", affirm => "yeah!"} };
$last_log = one_row("test_log", -order_by => {-desc => "id"});
ok( $last_log->action eq 'works further'
	  && $last_log->result eq 'OK'
	  && $last_log->level eq 'debug'
	  && $last_log->comment eq q{ohhh; "affirm":"yeah!"},
	'second dbi test'
);

done_testing();