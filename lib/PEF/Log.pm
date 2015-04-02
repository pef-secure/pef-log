package PEF::Log;
use strict;
use warnings;
use Time::HiRes qw(time);

our $start_time;
our $last_log_event;
our $caller_offset = 0;

BEGIN {
	$start_time = time;
	$last_log_event = 0;
}


1;