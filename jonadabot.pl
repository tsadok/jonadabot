#!/usr/bin/perl

$|=1;
use strict;
use warnings;

use Carp;
use Mail::POP3Client;
use Data::Dumper;
use AnyEvent;
use AnyEvent::IRC::Client;
use AnyEvent::IRC::Util;
use DateTime;
use Mail::Sendmail;
use Digest::SHA256;
use AnyEvent::ForkManager;
use File::Spec::Functions;
use HTML::Entities;
use DateTime::Format::Mail;

our $cfgprofile = ((grep { $_ } map { /^cfgprofile=(\w+)/; $1 } @ARGV), 'jonadabot')[0];
print "Using config profile: $cfgprofile\n";
our $servertz = 'undef'; # We need to know the timezone of the computer the bot runs on:
do "timezone.pl"; $servertz or die "FATAL Error: servertz not set\nYou need to create a timezone.pl, see timezone_sample.pl for an example.\n";

our $devname          = 'jonadabot';
our $author           = 'Jonadab the Unsightly One';
our $version          = '007';
our $devstatus        = 'alpha';
our $gitpage          = 'https://gitorious.org/jonadabot';
our $logfile          = "/var/log/jonadabot_$version.log";
our $utilsubs         = "jonadabot_utilsubs.pl";
our $extrasubs        = "jonadabot_extrasubs.pl";
our $guts             = "jonadabot_guts.pl";
our $regexen          = "jonadabot_regexes.pl";
our $teacode          = "jonadabot_teacode.pl";
our $dbcode           = "jonadabot_db.pl";
our $watchlog         = "jonadabot_filewatch.pl";
our $defaultusername  = "jonadabot_" . $version . "_" . (65535 + int rand 19450726);


my @tz                = ( time_zone => $servertz );
our %friendlytzname   = ('America/New_York'    => [ 'EST', 'EDT'  ], # This is the problem with using cities:
                         'America/Detroit'     => [ 'EST', 'EDT'  ], # You get duplicate names for the same zone.
                         'America/Chicago'     => [ 'CST', 'CDT'  ], # People say, "WHAT?  I'm nowhere near New York."
                         'America/Denver'      => [ 'MST', 'MDT'  ], # "I don't even know what timezone New York is in."
                         'America/Los_Angeles' => [ 'PST', 'PDT'  ], # "That's like a two-day drive from here."
                         'Europe/London'       => [ 'GMT', 'BST'  ], # It is in fact exactly the same timezone,
                         'Europe/Paris'        => [ 'CET', 'CEST' ], # but people who haven't studied timezones
                         'Europe/Berlin'       => [ 'CET', 'CEST' ], # don't know this; so it gets another name,
                         'Europe/Rome'         => [ 'CET', 'CEST' ], # and another, and another, and another...
                         'Europe/Istanbul'     => [ 'EET', 'EEST' ], # So despite only having thirty or forty
                         'Europe/Kiev'         => [ 'EET', 'EEST' ], # actual time zones in the world, we have
                         'Europe/Moscow'       => [ 'MSK', 'MSK'  ], # several hundred of them on the list.
                         'Asia/Jerusalem'      => [ 'IST', 'IDT'  ], # The list is too long to reproduce here.
                         'Asia/Damascus'       => [ 'EET', 'EEST' ], # Very much too long.  So I won't try.
                         'Asia/Taipei'         => [ 'CST', 'CST'  ], # If a timezone is not listed here,
                         'Asia/Shanghai'       => [ 'CST', 'CST'  ], # all that happens is the bot will fall back
                         'Asia/Tokyo'          => [ 'JST', 'JST'  ], # to calculating the friendly name at run
                         'Asia/Seoul'          => [ 'KST', 'KST'  ], # time.  That'll have to be good enough.
                         'Australia/Sydney'    => [ 'EST', 'EST'  ], # Actually, it's tempting to just rip out
                         'Australia/Canberra'  => [ 'EST', 'EST'  ], # this hash entirely and use the runtime
                         'Australia/Melbourne' => [ 'EST', 'EST'  ], # calculation exclusively.
                         'Australia/Adelaide'  => [ 'CST', 'CST'  ],
                         'Australia/Darwin'    => [ 'CST', 'CST'  ],
                         'Australia/Perth'     => [ 'WST', 'WST'  ],
                        );

our $startuptime      = DateTime->now(@tz);


my @stage = ("'Aleph", qw(Beth Gimmel Daleth He Waw Zayin Heth Teth Yodh Kaph Lamedh Mem Nun Samekh), "`Ayin", qw(Pe Tsadhe Qoph Resh Sin Shin Taw));
warn "Stage " . (shift @stage);
our (%watchregex); # Populated with regexes by jonadabot_regexes.pl, which each installation must supply (there's a sample).
do $utilsubs;  warn "Stage " . (shift @stage) . " (did utilsubs)";
do $dbcode;    warn "Stage " . (shift @stage) . " (did dbcode)";
do $regexen;   warn "Stage " . (shift @stage) . " (did regexes)";
do $extrasubs; warn "Stage " . (shift @stage) . " (did extrasubs)";
do $teacode;   warn "Stage " . (shift @stage) . " (did tea code)";
#do $dbcode;   warn "Stage " . (shift @stage) . " (did db code)";
our (%debug, %irc, %prefdefault, @notification, @scriptqueue, $jotcount);
do $guts;      warn "Stage " . (shift @stage) . " (did guts)";

# Rudimentary restart-flood protection:
my @recentstart = getsince('startuprecord', 'whenstarted', $startuptime->clone()->subtract( hours => 3 ));
my @veryrecent  = getsince('startuprecord', 'whenstarted', $startuptime->clone()->subtract( minutes => 20 ));
if (scalar @veryrecent) {
  my $sleeptime = 5 * ((scalar @recentstart) * (scalar @veryrecent));
  logit("We have restarted " . @veryrecent . " times very recently, "
        . @recentstart . " times somewhat recently, sleeping for $sleeptime seconds.");
  print "We have restarted " . @veryrecent . " times very recently, "
        . @recentstart . " times somewhat recently, sleeping for $sleeptime seconds...\n";
  while ($sleeptime) {
    print(($sleeptime > 9) ? "." : $sleeptime);
    print " \t($sleeptime left)\n" if not $sleeptime % 60;
    $sleeptime--;
    sleep 1;
  }
  print "\n";
}

logit("Attempting to start $devname $version $devstatus, by $author", 1);
addrecord('startuprecord', +{
                             whenstarted => DateTime::Format::ForDB($startuptime),
                             psid        => $$, }, );

warn "Stage " . (shift @stage) . " (added startup record)";

our %botwatch;
use Data::Dumper; warn Dumper(+{ debug => \%debug });
do $watchlog;
warn "Stage " . (shift @stage) . " (did file watch)";
use Data::Dumper; warn Dumper(+{ debug => \%debug });
my @log = getrecord("logfile");
warn "Database contains " . @log . " log files.\n";
@log = grep { not $$_{flags} or not ($$_{flags} =~ /X/)
            } @log;
warn "   Filtered out all but " . @log . " of them.\n";
for my $log (@log) { # X means disabled.
  warn "      Considering $$log{mnemonic}\n" if $debug{filewatch};
  logit("Considering $$log{mnemonic} log ($$log{id})", 3) if $debug{filewatch};
  my $logfile = $$log{logfile};
  my @watch   = grep { not $$_{flags} or not ($$_{flags} =~ /X/)
                     } findrecord("logfilewatch", "logfile", $$log{id});
  if (@watch) {
    my $pipe;
    open $pipe, "tail -f $logfile |";
    logit("Pipe created for log $$log{id}", 4) if $debug{filewatch} > 1;
    $botwatch{$$log{id}}{pipe} = $pipe;
    $botwatch{$$log{id}}{watcher} = AnyEvent->io( fh   => $pipe,
                                                  poll => "r",
                                                  cb   => sub {
                                                    watchlogfile($log, \%botwatch);
                                                  },
                                                );
    logit("Watcher established for log $$log{id}", 4) if $debug{filewatch} > 1;
  } else {
    logit("No enabled watches on this logfile, skipping.", 4) if $debug{filewatch};
  }
}
warn "Stage " . (shift @stage) . " (opened pipes)";

# TODO: use the condvars for each IRC network; it should be possible for
#       a master trigger to result in their being sent;l when received,
#       the connection to that network should be disconnected and then
#       reconnected.  The shutdown sequence, then, should reap all of
#       them, to get rid of the ugly kill $$ hack we are currently using.
#       A global flag var set by !shutdown can prevent the reconnects.

for my $ircnet (findrecord("ircnetwork", cfgprofile => $cfgprofile, enabled => 1)) {
  my $netid = $$ircnet{id};
  $irc{$netid}{condvar}      = AnyEvent->condvar;
  $irc{$netid}{networkname}  = $$ircnet{networkname};
  $irc{$netid}{networkflags} = $$ircnet{flags};
  $irc{$netid}{client}       = new AnyEvent::IRC::Client;

  our $timer; # TODO: Does this need to be per-network?

  warn "Stage " . (shift @stage) . " (created IRC client for network $netid, $irc{$netid}{networkname})";
  my $irc = $irc{$netid}{client};
  $irc->reg_cb (connect => sub {
                my ($con, $err) = @_;
                logit("Callback: connect (preparing to 'register' nick on $irc{$netid}{networkname})");
                if (defined $err) {
                  error("connect", $err);
                  $irc{$netid}{condvar}->send();
                  exit 1;
                } else {
                  my @nick = getconfigvar($cfgprofile, $netid, "ircnick");
                  my $user = getconfigvar($cfgprofile, $netid, "ircusername");
                  my $pass = getconfigvar($cfgprofile, $netid, "ircpassword");
                  my $real = getconfigvar($cfgprofile, $netid, "ircrealname");
                  $irc{$netid}{client} = $irc = $con; # Not sure if this is necessary.
                  $irc->register($nick[0], $user, $real, $pass);
                  # For historical reasons, the register() method appears misnamed, from a modern
                  # perspective.  It doesn't register a new account with services.  (Early IRC
                  # networks didn't even have such things.)  You have to do it every time you
                  # connect.  It's rather like logging in, only without any authentication.
                  # The authentication step, then, is next:
                  select undef, undef, undef, 0.1;
                  my $nsrv = scalar getconfigvar($cfgprofile, "ircnickserv");
                  $irc->send_srv( PRIVMSG => ($nsrv),
                                  "identify " . getconfigvar($cfgprofile, "ircpassword"),
                                ); # This is the authentication step.
                  select undef, undef, undef, 0.1;
                  if ($debug{groupnick}) {
                    for my $nick (reverse @nick) {
                      $irc->send_srv( NICK => $nick, );
                      select undef, undef, undef, 0.1;
                      $irc->send_srv( PRIVMSG => $nsrv, "identify $user $pass", );
                      select undef, undef, undef, 0.1;
                      $irc->send_srv( PRIVMSG => $nsrv, "GROUP", );
                      select undef, undef, undef, 0.1;
                    }
                  } else {
                    my $nick = $nick[0];
                    $irc->send_srv( NICK => $nick, );
                      select undef, undef, undef, 0.1;
                  }
                  $irc->send_srv( PRIVMSG => $_, "I'm in ($$).", )
                    for uniq(getconfigvar($cfgprofile, "defaultoperator"),
                             getconfigvar($cfgprofile, "operator"));
                  select undef, undef, undef, 0.1;
                  for my $chan (getconfigvar($cfgprofile, "ircchannel")) {
                    $irc->send_srv( JOIN => $chan );
                    select undef, undef, undef, 0.1;
                  }
                  settimer();
                }
              });
warn "Stage " . (shift @stage) . " (connected to IRC)";
$irc->reg_cb (registered => sub { logandprint("I'm in ($$)!\n"); });
$irc->reg_cb (disconnect => sub { logandprint("I'm out ($$)!\n");
                                  $condvar->broadcast; exit 1; });

$irc->reg_cb (channel_add => sub { my ($client, $msg, $channel, @nick) = @_;
                                   addnicktochannel($channel, @nick); });
$irc->reg_cb (channel_remove => sub { my ($client, $msg, $channel, @nick) = @_;
                                      removenickfromchannel($channel, @nick); });
$irc->reg_cb (channel_change => sub { my ($client, $msg, $channel, $old, $new, $isme) = @_;
                                      # TODO: track aliases in the database, maybe use whois to determine canonicality
                                      $irc{channel}{lc $channel}{alias}{$new}{$old}++;
                                      $irc{channel}{lc $channel}{alias}{$old}{$new}++;
                                      addnicktochannel($channel, $new);
                                      removenickfromchannel($channel, $old);
                                    });
$irc->reg_cb (privatemsg => sub {
                my ($client, $nick, $ircmessage )= @_;
                logit("Callback: privatemsg") if $debug{irc} > 3;
                print Dumper(+{ event => 'privatemsg',
                                nick  => $nick,
                                messg => $ircmessage,
                              }) if $debug{privatemsg} > 5;
                my ($recipient, $text) = @{$$ircmessage{params}};
                logit("Private Message from $$ircmessage{prefix}: $text", 1) if $debug{privatemsg} > 1;
                handlemessage($$ircmessage{prefix}, $text, 'private');
              });
$irc->reg_cb (error => sub { my ($client, $code, $msg, $ircmsg) = @_;
                             logit("Callback: error") if $debug{irc} > 3;
                             my $name = AnyEvent::IRC::Util::rfc_code_to_name($code);
                             error(qq[$code, $name], $msg);
                           });

$irc->reg_cb(publicmsg => sub { my ($client, $channel, $ircmsg) = @_;
                                logit("Callback: publicmsg") if $debug{irc} > 3;
                                print Dumper(+{ event   => 'publicmsg',
                                                channel => $channel,
                                                messg   => $ircmsg,
                                              }) if $debug{publicmsg} > 5;
                                my $text;
                                ($channel, $text) = @{$$ircmsg{params}};
                                handlemessage($$ircmsg{prefix}, $text, $channel);
             });
$irc->reg_cb(ctcp => sub { my ($src, $target, $tag, $msg, $type, $blah) = @_;
                           logit("Callback: ctcp") if $debug{irc} > 3;
                           handlectcp($src, $target, $tag, $msg, $type, $blah);
             });

warn "Stage " . (shift @stage) . " (registered callbacks)";

my $serv = getconfigvar($cfgprofile, "ircserver")     || 'irc.freenode.net';
my $port = getconfigvar($cfgprofile, "ircserverport") || 6667;
my @nick = getconfigvar($cfgprofile, "ircnick")       || $defaultusername;
my $user = getconfigvar($cfgprofile, "ircusername")   || $defaultusername;
my $real = getconfigvar($cfgprofile, "ircrealname")   || qq[anonymous irc bot operator];
my $pass = getconfigvar($cfgprofile, "ircpassword")   || shadigest(join "|", $0, $cfgprofile, $serv, @nick, $user, $real);

our @identification = (nick     => $nick[0],
                       user     => $user,
                       real     => $real,
                       password => $pass);
logit("Connecting (cfgprofile: $cfgprofile; server: $serv; port: $port; idenfication: @identification)")
  if $debug{connect};
$irc->connect($serv, $port, { @identification });
warn "Stage " . (shift @stage) . " (connected/waiting)";
logit("Waiting");
$condvar->wait;
logit("Waited");
warn "Stage " . (shift @stage) . " (waited)";

while (not $irc->registered()) {
  jot("?");
  select undef, undef, undef, 0.25;
  die "Unable to register nick." if $jotcount > 100;
}
warn "Stage " . (shift @stage) . ' ("registered" nick)';

for our $chan (@{$irc{chan}}) { # This is probably redundant.
  logandprint("Attempting to join $chan");
  $irc->send_srv( "JOIN", $chan );
}
warn "Stage " . (shift @stage) . " (joined channels)";

our $loopcount = 98;
while (1) {
  if (not ++$loopcount % 200) {
    jot();
  }
  select undef, undef, undef, 0.15;
}

warn "Stage " . (shift @stage) . " (exited while loop)";
$condvar->wait();
warn "Stage " . (shift @stage) . " (waited again)";
$irc->disconnect();
warn "Stage " . (join "", map { $_ . " (disconnected)" . $/ } @stage);

sub shadigest {
  my (@input) = @_;
  my $usrsalt = join "|", $<, $>, $(, $), $0;
  my $syssalt = `hostname`;
  my $appsalt = qq[pD1t65UCJSMrILztSRO_eV7WY1AOYykLm0GAB5jk7zDEbrFmALMAtlNucEkSDN1rerDPpRNR6Olze43j];
  my $context = Digest::SHA256::new(384);
  my $salted  = join " :-: ", $usrsalt, $syssalt, @input, $appsalt;
  $context->reset();
  $context->add($salted);
  my $answer = $context->hexhash($salted);
  return $answer;
}

