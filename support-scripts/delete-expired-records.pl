#!/usr/bin/perl

our $dbcode           = "jonadabot_db.pl";
our $utilsubs         = "jonadabot_utilsubs.pl";

use DateTime;
use DateTime::Format::MySQL;
my $now = DateTime->now();

our $cfgprofile       = askuser("Enter the identifier for your configuration profile (default: jonadabot)") || 'jonadabot';

my $daysago = 7;
for my $arg (grep { /days(?:ago)?=(\d+)/ } @ARGV) {
  $daysago = $1 || $daysago;
}
my $whendt = $now->clone()->subtract( days => $daysago + 1 ); # The +1 means we can ignore timezones here.
my $when   = DateTime::Format::ForDB($whendt);

# Always do startup records, because they are redundant with the log.
# The only reason we even keep them in the DB is for restart-flood protection.
print "Doing startup records...\n";
my @exp = grep { $$_{whenstarted} lt $when } getrecord('startuprecord');
for my $expired (@exp) {
  deleterecord('startuprecord', $$expired{id});
}

# Only do logfile-line announcements if the person running the script says so.
# Note that for logfiles that only update very rarely, you may want a rather
# larger daysago value for these than for other categories; otherwise you can
# get repeat announcements hours after the bot restarts, when the /next/
# line is written to the log, which confuses people greatly.
if (grep { /announcement/i } @ARGV) {
  print "Doing logfile-line announcements...\n";
  @exp = grep { $$_{expires} lt $when } getrecord('announcement');
  for my $expired (@exp) {
    deleterecord('announcement', $$expired{id});
  }
}

# Only do mailqueue if the person running the script says so:
if (grep { /mail/i} @ARGV) {
  print "Doing mail queue...\n";
  @exp = grep { $$_{dequeued} lt $when } getrecord('mailqueue');
  for my $expired (@exp) {
    deleterecord('mailqueue', $$expired{id});
  }
}

# only do memoranda if the person running the script says so:
# (memoranda are the !tell messages users leave one another)
if (grep { /memo/i} @ARGV) {
  @exp = grep { $$_{status} == 2 } getrecord('memorandum');
  for my $expired (@exp) {
    deleterecord('memorandum', $$expired{id});
  }
}

# Only do user alarms if the person running the script says so:
if (grep { /alarm/i} @ARGV) {
  print "Doing alarms...\n";
  @exp = grep { $$_{status}
                  and $$_{viewed} and ($$_{viewed} lt $when)
                  and ($$_{alarmdate} lt $when)
                  and ((not $$_{snoozetill}) || ($$_{snoozetill} lt $when))
                  and (not ($$_{flags} =~ /K/)) # K stands for Keep-on-Record
                } getrecord('alarm');
  for my $expired (@exp) {
    deleterecord('alarm', $$expired{id});
  }
}

