#!/usr/bin/perl


use AnyEvent::IRC::Util qw(encode_ctcp);

our %demilichen; # populated later

our %debug = ( # TODO: override these defaults from the DB, after the DB code is loaded.
              alarm      => 7,
              biff       => 1,
              bottrigger => 1,
              connect    => 2,
              ctcp       => 1,
              echo       => 0,
              filewatch  => 7,
              groupnick  => 0,
              irc        => 0,
              login      => 0,
              pingtime   => 1,
              pop3       => 1,
              preference => 3,
              privatemsg => 0,
              publicmsg  => 0,
              say        => 0,
              smtp       => 7,
              tea        => 0,
            );


%prefdefault = (
                timezone => 'UTC',
               );

my $defaultusername = "jonadabot_" . $version . "_" . (65535 + int rand 19450726);
my $ourclan = getconfigvar($cfgprofile, 'clan') || 'demilichens'; # used more than one place below.
%irc = (
        server  => getconfigvar($cfgprofile, 'ircserver') || 'irc.freenode.net',
        port    => getconfigvar($cfgprofile, 'ircserverport') || 6667,
        nick    => [ getconfigvar($cfgprofile, 'ircnick'), $defaultusername ],
        nsrv    => getconfigvar($cfgprofile, 'ircnickserv') || 'NickServ',
        user    => getconfigvar($cfgprofile, 'ircusername') || $defaultusername,
        real    => ("" . getconfigvar($cfgprofile, 'ircrealname') || "anonymous ircbot operator") . ", represented by $devname",
        pass    => getconfigvar($cfgprofile, 'ircpassword') || 'm2RTLVG8iwm3onyNzFXSu0kOYFtdlGB5Nct',
        email   => getconfigvar($cfgprofile, 'ircemailaddress'),
        clan    => $ourclan,
        demi    => [ getclanmemberlist($ourclan) ],
        chan    => ['#bot-test',
                   #'#bot-testing',
                   #'#bottesting',
                   getconfigvar($cfgprofile, 'ircchannel'),
                  ],
        channel => +{}, # populated only when channels are joined
        okdom   => +{ map { $_ => 1 } (getconfigvar($cfgprofile, 'ircchanokdom'), 'private')}, # channels it's ok to dominate
        silent  => +{ map { $_ => 1 } (getconfigvar($cfgprofile, 'ircchansilent'), '#freenode')}, # exact opposite, channels to shut up in
        oper    => getconfigvarordie($cfgprofile, 'defaultoperator'), # Primary nick for primary bot operator.
        opers   => [uniq(getconfigvar($cfgprofile, 'defaultoperator'),
                         getconfigvar($cfgprofile, 'operator')),
                    # All active GROUPed nicks for primary bot operator.
                    # Currently this doesn't do much, but in a
                    # future version the bot will look for you and
                    # find which nick you are using if you are
                    # online.
                   ],
        master  => +{ map { $_ => 1 }
                      (getconfigvar($cfgprofile, 'master')
                       # Any nick listed as master can issue any
                       # bot command, including privileged ones.
                       # Don't list unregistered nicks as master,
                       # for obvious reasons.  Nicks can be listed
                       # as master without being the operator, and
                       # vice versa.
                      ),
                    },
        maxlines => getconfigvar($cfgprofile, 'maxlines') || 12,
        pinglims => [getconfigvar($cfgprofile, 'pingtimelimit')],
        pingtime => DateTime->now( @tz ),
        pingbots => [getconfigvar($cfgprofile, 'pingbot')], # Bots that will respond to !ping in a private /msg
        siblings => [getconfigvar($cfgprofile, 'sibling')], # "buddy system"; if they go offline, we /msg our operator.
       );

our @notification = (); # TODO: store notifications in the database and purge this variable.
our @scriptqueue  = (); # This one can stay, because it gets emptied quickly.

our $jotcount;
sub jot {
  my ($c) = @_;
  print $c;
  print "\n" if not ++$jotcount % 60;
}

sub logit {
  my ($msg, $level) = @_;
  $level ||= 2;
  open LOG, ">>", $logfile;
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  print LOG "$year/$mon/$mday $hour:$min:$sec " . ("   " x ($level - 1)) . $msg . "\n";
  close LOG;
}
sub logandprint {
  my ($msg, $level) = @_;
  warn "$msg\n";
  logit($msg, $level || 2);
}
sub error {
  my ($errortype, $message) = @_;
  warn "$errortype error: $message\n";
  logit("ERROR: $errortype: $message");
}

sub isclanmember {
  my ($username) = @_;
  return findrecord('clanmembersrvacct', 'serveraccount', $username);
}

sub settimer {
  my $count;
  $irc{fork} = AnyEvent::ForkManager->new( max_workers => 12 );
  $irc{fork}->on_start(sub { my ($fork, $pid, @arg) = @_;
                             logit("Starting fork $fork, pid $pid, @arg") if $debug{fork};
                       });
  $irc{fork}->on_finish(sub { my ($fork, $pid, $status, @arg) = @_;
                              logit("Finished fork $fork, pid $pid, status $status, @arg");
                        });
  $irc{timer}{ping} = AnyEvent->timer(
                                      after    => 5,
                                      interval => 10,
                                      cb       => sub {
                                        checkpingtimes();
                                      });
  $irc{timer}{biff} = AnyEvent->timer(
                                      after    => 60,
                                      interval => 15,
                                      cb       => sub {
                                        if (@notification) {
                                          processnotification();
                                        } else {
                                          biff($irc{oper}) if not $count++ % 25;
                                        }
                                      }
                                     );
  $irc{timer}{script} = AnyEvent->timer(
                                        after    => 15,
                                        interval => 5,
                                        cb       => sub {
                                          if (@scriptqueue) {
                                            #my ($fork, @arg) = @_;
                                            my $sqitem = shift @scriptqueue;
                                            $irc{fork}->start( cb => sub {
                                                                 doscript($sqitem);
                                                               });
                                          }
                                        }
                                       );
  $irc{timer}{alarms} = AnyEvent->timer(
                                        after    => 5,
                                        interval => (60 * (getconfigvar($cfgprofile, 'alarmresminutes') || 5)),
                                        cb       => sub { checkalarms(); },
                                       );
  $irc{timer}{smtp} = AnyEvent->timer(
                                      after    => 60,
                                      interval => 17, # never send more than one message every this many seconds
                                      cb       => sub {
                                        $irc{fork}->start( cb => sub {
                                                             sendqueuedmail();
                                                           });
                                      },
                                     );
  # additional timers could be added here for more features.
}

sub sendqueuedmail {
  my @queue = findnull("mailqueue", 'dequeued');
  return if not @queue;
  my $msg = $queue[rand @queue];
  my ($hostname) = (`/bin/hostname` =~ /(\S+)/);
  my $server = getrecord('smtp');
  $Mail::Sendmail::mailcfg{retries} = 7;
  $Mail::Sendmail::mailcfg{delay}   = 113;
  $Mail::Sendmail::mailcfg{smtp}    = [ $$server{server} ];
  my %mail = ( From        => $$msg{fromfield} || getconfigvar($cfgprofile, 'ircemailaddress'),
               Subject     => $$msg{subject} || 'Message from IRC ($irc{nick})',
               Bcc         => $$msg{bcc},
               To          => $$msg{tofield},
              #'User-Agent' => qq[$devname $version (operated on $hostname by $irc{oper})],
               # TODO: Date based on the enqueued datetime
               message     => $$msg{body},
             );
  $$msg{trycount}++;
  warn "No nick for message $$msg{id}" if not $$msg{nick};
  if (sendmail(%mail)) {
    $$msg{dequeued} = DateTime::Format::ForDB(DateTime->now(@tz));
    say("Email message #" . $$msg{id} . " sent to $$msg{to}.",
        channel => 'private', sender => $$msg{nick});
  } else {
    logit("SMTP error: $Mail::Sendmail::error");
    say($Mail::Sendmail::error, channel => 'private', sender => $$msg{nick});
  }
  updaterecord('mailqueue', $msg);
}

sub checkalarms {
  my $now   = DateTime->now(@tz);
  my $dbnow = DateTime::Format::ForDB($now);
  my @alarm = grep { $$_{alarmdate} le $dbnow } findrecord('alarm', 'status', 0);
  if (@alarm) {
    @alarm = grep { (not $$_{snoozetill}) or ($$_{snoozetill} le $dbnow) } @alarm;
    for my $alarm (@alarm) {
      my $ftime = friendlytime($now, getircuserpref($$alarm{nick}, 'timezone')|| $prefdefault{timezone});
      my $says  = ($$alarm{sender} eq $$alarm{nick}) ? '' : qq[$$alarm{sender} says];
      warn "No nick for alarm $$alarm{id}" if not $$alarm{nick};
      say("It's ${ftime}: [$$alarm{id}] $says$$alarm{message}", sender => $$alarm{nick}, channel => 'private');
      # TODO: if the user's not ON at the moment, enqueue a !tell instead
      $$alarm{viewcount}++;
      $$alarm{viewed} = $dbnow;
      $$alarm{status} = 1;
      updaterecord('alarm', $alarm);
    }
  }
}

sub doscript {
  my ($item) = @_;
  my ($script, $args, $callback, $cbargs) = @$item;
  system($script, @$args);
  $callback->(@$cbargs);
}

sub updateseen { # Don't call directly; call updatepingtimes() instead.
  my ($dt, $nick, $channel, $text) = @_;
  my @s = findrecord('seen', nick => $nick);
  my $whenseen = DateTime::Format::ForDB($dt);
  if (@s) {
    logit("Too many seen records for $nick") if 1 < scalar @s;
    my $s = $s[0];
    $$s{whenseen} = $whenseen;
    $$s{channel}  = $channel;
    $$s{details}  = $text;
    updaterecord('seen', $s);
  } else {
    addrecord('seen', +{ nick     => $nick,
                         whenseen => $whenseen,
                         channel  => $channel,
                         details  => $text,
                       });
  }
}

sub updatepingtimes {
  my ($sender, $channel, $text) = @_;
  my $oldtime = $irc{pingtime};
  $irc{pingtime} = DateTime->now(@tz);
  logit("Updated pingtime from $oldtime to $irc{pingtime}",3) if $debug{pingtime} > 6;
  updateseen($irc{pingtime}, $sender, $channel, $text);
}
sub checkpingtimes {
  my $now   = DateTime->now(@tz);
  logit("Checking ping times at " . $now->hms(),3) if $debug{pingtime} > 3;
  my @bot = @{$irc{pingbots}};
  if (not scalar @{$irc{pinglims}}) { push @{$irc{pinglims}}, 30;
                                      push @{$irc{pinglims}}, 45; }
  if (not scalar @{$irc{pingbots}}) { push @{$irc{pingbots}}, 'Arsinoe'; }
  for my $lim (@{$irc{pinglims}}) {
    my $bot = shift @bot;
    logit("lim $lim, bot $bot", 3) if $debug{pingtime} > 4;
    my $pt  = $irc{pingtime} || $now;
    my $limit = $pt->clone()->add( seconds => $lim );
    logit("now $now, limit $limit", 4) if $debug{pingtime} > 5;
    return if $limit > $now;
    logit("Past ping limit ($lim seconds), pinging $bot");
    say("!ping", channel => 'private', sender => $bot);
    push @bot, $bot;
  }
  logit("Past all ping limits.  Restarting...");
  exec "jonadabot.pl";
  logit("exec returned (checkpingtimes)", 1);
  system("kill", $$);
  sleep 3;
  system("kill", "-9", $$);
  sleep 3;
  logit("I am immortal, but I am all alone.", 1);
}

sub greeting { # punctuation may be added automatically, so don't include it
  my @g = (# Basic English:
           "Hi", "Hi", "Hello", "Hello", "Howdy",
           "Welcome", "Greetings",
           # Common foreign ones:
           "Bonjour", "Buenos dias", "Aloha", "Hallo", "Hola",
           # Exotic English:
           "Salutations", "G'day", "Wassup", "Hey",
           # Semi-exotic foreign:
           "Konnichiwa", "Qapla'", "Shalom", "Salve", "Ola",
           # Exotic foreign:
           "Kaixo", "Zdravo", "Saluton", "Hei", "Bonjou", "Alo",
           "Nyob zoo", "Ndewo", "Sveiki", "Ahoj", "Pozdravljeni",
           "Habari", "Merhaba", "Kaabo", "Sawubona", "Aiya",
           "Rimaykullayki", "Haai", "Werte", "Halito",
           # And finally...
           "Hello, will you please leave your ki-rin outside",
          );
  return $g[int rand rand int rand @g];
}
sub addnicktochannel { # Currently, we don't actually /use/ these lists for anything.
  my ($ch, @n) = @_;
  $irc{channel}{lc $ch}{nicks} = [ sort { $a cmp $b
                                     } uniq(@n, @{$irc{channel}{$ch}{nicks}}) ];
  #my $now = DateTime->now( @tz );
  #$irc{channel}{lc $ch}{seen}{lc $_} = $now for @n;
  if (($irc{okdom}{$ch}) and (rand(100)<(getconfigvar($cfgprofile, 'hellochance') || 27))) {
    say((join ", ", greeting(), @n),
        channel => $channel, sender => $n[0]);
  }
}
sub removenickfromchannel {
  my ($ch, @n) = @_;
  my %remove = map { $_ => 1 } @n;
  $irc{channel}{lc $ch}{nicks} = [ grep {
    not $remove{$_}
  } @{$irc{channel}{lc $ch}{nicks}} ];
}

sub parseprefix { # This function needs work.  I'm still finding cases it
                  # doesn't parse correctly, mainly because the cretin
                  # who wrote it has only a very limited knowledge of IRC.
  my ($prefix, $caller) = @_;
  my ($nick, $otherthing, $user, $ipordomain)
    = $prefix =~ m%^(\w+)          # nick
                   (?:[!](\w*))?   # otherthing -- totally optional
                   (?:[~](\w*))?   # user -- optional, not always included
                   (?:[@](\d+[.]\d+[.]\d+[.]\d+|(?:\w+[.])+\w{2,3}|(?:\w+[-]?[.]?)+[.]\w+|unaffiliated/\w+|services.?))?%x;
  logit("Failed to parse prefix: <$prefix>, called via: $caller") if not $nick;
  if ($nick) {
    if (wantarray) {
      return ($nick, $otherthing, $user, $ipordomain);
    } else {
      return $nick;
    }
  }
  return;
}

sub say {
  my ($message, %arg) = @_;
  print $message . "\n" if $debug{say};
  my $target = ($arg{channel} eq 'private') ? $arg{sender} : $arg{channel};
  logit("say [to $target]: $message") if $debug{say} > 1;
  if (($arg{channel} eq 'private') and ($arg{sender})) {
    #$message =~ s~^/me ~$irc{nick}[0] ~;
    if ($message =~ m!^/me !) { # TODO: test this.
      $message =~ s!^/me (.*)!ACTION $1!;
    }
    $irc->send_srv(PRIVMSG => $arg{sender}, $message);
  } elsif ($arg{force}) {
    $irc->send_srv(PRIVMSG => $arg{channel}, $message);
  } elsif ((grep { $_ eq $arg{channel} } @{$irc{chan}})
           and not $irc{silent}{$arg{channel}}) {
    # We're in the channel, so it's probably OK to respond there.
    # But not too frequently...
    my @myrecent = grep { /^Arsinoe/ } @{$irc{channel}{lc $arg{channel}}{recentactivity}};
    if ((5 >= @myrecent) or ($irc{okdom}{$arg{channel}})) {
      #$message =~ s~^/me ~$irc{nick}[0] ~;
      if ($message =~ m!^/me !) {
        $message =~ s!^/me (.*)!ACTION $1!;
      }
      $irc->send_srv(PRIVMSG => $arg{channel}, $message);
    } elsif ($arg{fallbackto} eq 'private') {
      #$message =~ s~^/me (.*)~$irc{nick}[0] $1~;
      $message =~ s!^/me (.*)!ACTION $1!;
      $irc->send_srv(PRIVMSG => $arg{sender}, $message);
    }
  } else {
    if ($arg{channel} eq 'private') {
      print "No sender to return private message to.\n" if not $arg{sender};
    } else {
      if ($arg{channel}) {
        print "Not sure how to respond to channel '$arg{channel}'.\n";
      } else {
        print "No channel.\n" if $debug{say} > 4;
      }
      if ($arg{fallbackto} eq 'private') {
        if ($message =~ m!^/me !) {
          $message =~ s!^/me (.*)!ACTION $1!;
        }
        #$message =~ s~^/me ~$irc{nick}[0] ~;
        $irc->send_srv(PRIVMSG => $arg{sender}, $message);
      }
    }
  }
}

sub getircuserpref {
  my ($user, $var) = @_;
  if ($user) {
    my $r = findrecord('userpref', 'username', $user, 'prefname', $var);
    if (ref $r) {
      return $$r{value};
    } else {
      logit("Did not find preference $var for $user, using default, $prefdefault{$value}");
      return $prefdefault{$value};
    }
  } else {
    carp("Can't get irc user pref without a nick");
  }
}

sub setircuserpref {
  my ($user, $var, $value, %arg) = @_;
  my (@r) = findrecord('userpref', 'username', $user, 'prefname', $var);
  if (@r) {
    my $r = $r[0];
    logit("Too many values of pref $var for user $user") if 1 < scalar @r;
    $$r{value} = $value;
    updaterecord('userpref', $r);
    logit("Changing userpref $var to $value for $user") if $debug{preference} > 1;
  } else {
    addrecord('userpref', +{ username => $user, prefname => $var, value => $value });
    logit("Creating $var preference for $user") if $debug{preference};
  }
  my $newval = getircuserpref($user, $var);
  if ($newval eq $value) {
    say("New value for $var set.", sender => $user, fallbackto => 'private', %arg);
  } else {
    say("Something went wrong setting that variable.", sender => $user, fallbackto => 'private');
  }
}

sub getclanmemberlist {
  my ($clanname, $year) = @_;
  my $year  ||= DateTime->now( @tz )->year();
  my @member  = findrecord('clanmemberid', clanname => $clanname, year => $year );
  my @nickrec = map { findrecord('clanmembernick',    memberid => $$_{id}) } @member;
  my @srvarec = map { findrecord('clanmembersrvacct', memberid => $$_{id}) } @member;
  return uniq((map { $$_{tourneyaccount} } @member),
              (map { $$_{nick}           } @nickrec),
              (map { $$_{serveraccount}  } @srvarec),
             );
}

sub vladsbane {
  my @buc  = (qw(blessed blessed uncursed cursed cursed cursed), '');
  my @rust = ('rusty', 'very rusty', 'thoroughly rusty', 'rustproof', '');
  my @corr = ('corroded', 'very corroded', 'thoroughly corroded', '', '');
  my @burn = ('burnt', 'very burnt', 'fireproof', '', '');
  my @ench = ('', '', '', '', '', '', '', '+0', '+0', '+0', '+0',
              '+1', '+1', '+1', '+1', '-1', '-1', '-1',
              '+2', '+3', '+5', '+7', '-2', '-3', '-4', '-5');
  my @item =
    (
     ['dagger',     [@buc], [@rust, @corr, ''], [@ench], ['', 'orcish', 'crude'], ],
     ['club',       [@buc], [@rust, @burn, ''], ['thonged', '', '', ''], ],
     ["scalpel",    [@buc], [@rust, @corr, ''], [@ench], ],
     ['tin opener', [@buc], [@rust, @corr, ''], ],
     ["hands",      [],     ['bare', 'gloved'], ],
     ['potion',     [@buc], ['diluted', ''], [qw(yellow milky smoky clear fizzy effervescent)], ],
     ['icebox',     [@buc], [@rust, '', '', '', '', ''], [(('') x 15), 'full of corpses', 'full of booze'], ],
     ['stone',      [@buc], [qw(gray gray gray gray whitegem greengem redgem bluegem blackgem luck load flint)]],
    );
  my @adj = @{$item[rand @item]};
  my $baseitem = shift @adj;
  my $answer = join ' ', grep { $_ } ((map { my @l = @{$_}; $l[rand @l] } @adj), $baseitem);
  $answer =~ s/diluted clear/clear/;
  $answer =~ s/(luck|load) (stone)/$1$2/;
  $answer =~ s/gem / gem/;
  if ((rand(30) > 28) and (not $answer =~ /hands|icebox/)) {
    $num = 2 + int rand int rand int rand 5;
    $answer = $num . " " . $answer . "s";
  }
  return $answer;
}

sub helpinfo { # To avoid spamming the channel with a ton of irrelevant junk, only
               # unprivileged triggers (ones anyone can use) are documented here.
               # Bot operators and masters are expected to have a copy of the source.
  my ($item) = @_;
  if ($item eq '') {
    return "For more info: !help topic, where topic is deaths, gt, member, message, rng, seen, tea, tell, time, trophies";
  } elsif ($item eq 'deaths') {
    return '!deaths (refetches info from server), !deaths url (instant, does not fetch), !deaths reparse clan=$irc{clan}';
  } elsif ($item eq 'gt') {
    return "!gt clanmember or simply !gt, cheers on the team.";
  } elsif ($item eq 'member') {
    return "!member list, lists current known game server accounts of $irc{clan}; /msg $irc{oper} if yours is missing";
  } elsif ($item eq 'message') {
    return "!message [number]";
  } elsif ($item eq 'rng') {
    return "!rng choice A | choice B | choice C";
  } elsif ($item eq 'seen') {
    return "!seen whoever";
  } elsif ($item eq 'set') {
    return "!set timezone, specify in DateTime format (America/New_York for example)";
  } elsif ($item eq 'tea') {
    return "!tea, !juice, !tea whoever, !tea black whoever, !tea green whoever, !juice whoever";
  } elsif ($item eq 'tell') {
    return "!tell whoever Blah blah blah blah blah.";
  } elsif ($item eq 'time') {
    return "!time currently reports UTC.";
    #return "!time returns the current time in your timezone, see !help set";
  } elsif ($item eq 'trophies') {
    return qq[!trophies updates our "trophies needed" page and gives the URL when the update is complete.];
  }
}

sub debuginfo {
  my ($item, @arg) = @_;
  if ($item eq 'channels') {
    my @ch = keys %{$irc{channel}};
    logit("!DEBUG channels: " . join ", ", @ch);
    return "I have written a list to my log file.";
  } elsif ($item eq 'recent') {
    my ($channel) = @arg;
    my $count = 0;
    for my $r (@{$irc{channel}{lc $channel}{recentactivity}}) {
      ++$count;
      say("$count: $r", channel => 'private', sender => $irc{oper});
    }
    return "Sent $count lines of recent activity to $irc{oper}";
  } elsif ($item eq 'list') {
    return join "; ", map { qq[$_ => $debug{$_}] } sort { $a cmp $b } keys %debug;
  } elsif ($item =~ /set (\w+) (\d+)/) {
    my ($var, $val) = ($1, $2);
    if (exists $debug{$var}) {
      $debug{$var} = $val;
      return "Ok, set debug{$var} = $val";
    } else {
      return "Unknown debug variable: $var";
    }
  } elsif ($item =~ /show (\w+)/) {
    my $var = $1;
    if (exists $debug{$var}) {
      return "debug{$var} is currently $debug{$var}.";
    } else {
      return "Unknown debug variable: $var";
    }
  }
  return "I know nothing, nothing.";
}

sub handlectcp {
  my ($self, $target, $tag, $msg, $type, $blah) = @_;
  my $respond = 0;
  logit("handlectcp(self, $target, $tag, $msg, $type, $blah)");
  updatepingtimes($target, 'ctcp', $tag);
  if ($type eq 'NOTICE') { # The CTCP message was in a channel.  Only respond if sender is a master.
    $respond = ($irc{master}{$target}) ? 1 : 0;
  } elsif ($type eq 'PRIVMSG') { # The CTCP message was private.  Respond privately (if it's a tag we respond to).
    $respond = 1;
  }
  $respond++ if $irc{master}{$target}; # If the sender is our master, we may respond to some tags we otherwise would not.
  my $response = undef;
  logit("CTCP tag $tag, type $type, target $target, respond $respond, msg $msg");# if $debug{ctcp};
  if ($tag eq 'VERSION') {
    my $perlver  = ($] ge '5.006') ? (sprintf "%vd", $^V) : $];
    $response = qq[$devname $version / Perl $perlver];
  } elsif ($tag eq 'TIME') {
    my $dt       = DateTime->now(@tz);
    $response = $dt->year() . ' ' . $dt->month_abbr() . ' ' . $dt->mday() . ' at ' . ampmtime($dt) . ' ' . friendlytz($dt);
  } elsif ($tag eq 'PING') {
    if ($irc{master{$target}}) {
      # TODO: support PING fully
    } else {
      # TODO: support PING in a safer, more minimal way.
    }
  } # TODO: DCC support might be a useful way to deliver things like backscroll.
  logit("handlectcp: respond $respond, response $response", 3) if $debug{ctcp};
  if ($respond and $response) {
    say(encode_ctcp($tag, $response), channel => 'private', sender => $target);
  }
}

sub handlemessage {
  my ($prefix, $text, $howtorespond) = @_;
  # howtorespond should either be 'private' or a channel
  # The prefix is raw, as received by the callback.
  my $sender = parseprefix($prefix, qq[handlemessage('$prefix', '$text', '$howtorespond')]) || '__NO_SENDER__';
  warn("handlemessage: no sender") and return if not $sender;
  logit("parseprefix DRIBBLE: $prefix") if not $sender;
  my $fallbacktoprivate = 0;
  my $now = DateTime->now( @tz );
  # $irc{channel}{lc $howtorespond}{seen}{lc $sender} = $now; # Note that 'private' is treated as a channel.
  # ^ That's obsolete now that we are storing seen data in the DB.
  #   Now updateseen() is called by updatepingtimes(), below.
  #warn "[push irc{channel}{$howtorespond}, $sender]\n";
  $irc{channel} ||= +{};
  $irc{channel}{lc $howtorespond} ||= +{};
  logit("Adding $sender to recent activity list for channel $howtorespond");
  push @{$irc{channel}{lc $howtorespond}{recentactivity}}, $sender;

  while (20 < scalar @{$irc{channel}{lc $howtorespond}{recentactivity}}) { # Not-so-recent
     shift @{$irc{channel}{lc $howtorespond}{recentactivity}}
  }
  my $oldpingtime = $irc{pingtime};
  updatepingtimes($sender, $howtorespond, $text);
  my (@rec); # assigned in one of the conditionals below.
  if ($text =~ /^!tea\s*(black|green|herbal|white|oolang)*\s*(\w*)/) {
    my ($type, $namedrecipient) = ($1, $2);
    my $recipient = $sender; # Back to the user by default.
    if ($irc{master}{$namedrecipient}) {
      $recipient = $namedrecipient;
    } elsif (($namedrecipient =~ /^(Ars[ie]no|jonadabot)/) or (grep { $_ eq $namedrecipient } @{$irc{nick}})) {
      $recipient = undef;
    } elsif ($namedrecipient and haveseenlately($namedrecipient)) {
      $recipient = $namedrecipient;
    }
    if (rand(100) > 98) { $recipient = $sender; }
    tea( recipient => $recipient, channel => $howtorespond,
         sender => $sender, bev => ($type ? qq[$type tea] : undef),
         fallbackto => 'private', );
  } elsif ($text =~ /^!juice\s*(.*)/) {
    my ($namedrecipient) = $1;
    my $recipient = $sender; # Back to the user by default.
    if (($namedrecipient eq 'Rodney') or ($irc{master}{$namedrecipient})) {
      $recipient = $namedrecipient;
    } elsif ($namedrecipient =~ /^Ars[ie]noe/) {
      $recipient = undef;
    } elsif ($namedrecipient and haveseenlately($namedrecipient)) {
      $recipient = $namedrecipient;
    }
    if (rand(100) > 98) { $recipient = $sender; }
    juice(recipient => $recipient, channel    => $howtorespond,
          sender    => $sender,    fallbackto => 'private');
  } elsif ($text =~ /^!(coffee|beer|wine|booze|sake)\s*(.*)/) {
    my ($bev, $recipient) = ($1, $2);
    $recipient ||= $sender;
    my $pronoun = (getconfigvar($cfgprofile, 'botismale') ? "his" : "her");
    # Why is jonadabot styled female by default?  Because during early development it used the nick "Arsinoe".
    say("/me holds $pronoun nose and throws a mug of cold black coffee at $recipient",
        channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
  } elsif ($text =~ /^!deaths?\s*(.*)/) { # TODO: generalize this by allowing commands/scripts to be listed in the DB.
    my @extraarg = grep { /^(reparse|partial|url|clan=\w+)$/ } split /\s+/, $1;
    my $sayresults = sub {
      my (@arg) = @_;
      my $page = "deaths-needed.html";
      my @oclan = grep { /^clan=/} @arg; if (@oclan) {
        my ($oclan) = $oclan[-1] =~ /^clan=(\w+)/;
        $page = "deaths-$oclan.html";
      }
      say("http://74.135.83.0:8018/nethack-stuff/$page",
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
      if ($page eq 'deaths-needed.html') {
        say("http://74.135.83.0:8018/nethack-stuff/deaths-obtained.html",
            channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
      }
    };
    if (grep {/url/} @extraarg) {
      $sayresults->(@extraarg)
    } else {
      push @scriptqueue, ["perl", ["/b4/perl/nethack-junethack-unique-deaths.pl", @extraarg], $sayresults, \@extraarg];
    }
  } elsif ($text =~ /^!troph[yies]+\s*(.*)/) { # TODO: generalize this by allowing commands/scripts to be listed in the DB.
    my @extraarg = grep { /^(reparse|partial|url)$/ } split /\s+/, $1;
    my $sayresults = sub {
      say("http://74.135.83.0:8018/nethack-stuff/trophies-needed.html",
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
    };
    if (grep { /url/ } @extraarg) {
      $sayresults->(@extraarg);
    } else {
      push @scriptqueue, ["perl", ["/b4/perl/nethack-junethack-trophy-list-compiler.pl", @extraarg], $sayresults, \@extraarg];
    }
  } elsif ($text =~ /^!(hsn|lastgame|rc|dumplog|players|gamesby|scores|bugs|asc|ascension|lg|grepsrc|whereis|streak|save)\s*(.*)/) {
    # I wanted to add !wl to this list, but Rodney doesn't respond to it in /msg
    # TODO: generalize this by allowing info-source bots and triggers they can handle to
    #       be listed in the DB.  Note that to be useful the bot must trigger on a /msg
    #       and respond in kind.  If the command has to be given in a channel, we don't
    #       want to respond to it by issuing it, because that could cause loops and
    #       flooding and general unpleasantness.  If all we do is /msg a bot and route
    #       the answer to a channel, the worst that happens is duplicate responses.
    #       That's still not good, of course:  we shouldn't be proxying for a bot that
    #       frequents the same channel we're in; if we are it means we're misconfigured.
    #       But only using /msg to get the response should at least avoid loops.
    my ($command, $args) = ($1, $2);
    say($text, channel => 'private', sender => 'Rodney'); {
      # This isn't perfect.  In the event of lag, when multiple destination channels are
      # involved, responses to multiple proxied commands can end up all being echoed to
      # channels that only some of them were supposed to be echoed to (and note that
      # private /msg counts as a channel).  For small installations however this is
      # unlikely, unless one of the bots involved is lagging rather noticeably.
      $irc{echo}{Rodney}{private}{count}++;
      $irc{echo}{Rodney}{private}{channels} = [ uniq($howtorespond, @{$irc{echo}{Rodney}{private}{channels}}) ];
      push @{$irc{echo}{Rodney}{private}{fallback}}, $sender;
    }
  } elsif ($text =~ /^!ping\s*?( ?\w{0,20})/) {
    my ($userdata) = ($1);
    my ($extradata) = ($irc{master}{$sender} ? (qq[ $$ pt=] . $irc{pingtime}->hms()) : '');
    say("!pong$extradata $userdata", channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
  } elsif ($text =~ /^!vlads?bane/) {
    # TODO: generalize this sort of thing (probably also !tea, etc.) by listing valid
    #       trigger words in the database and then defining the subroutines for them
    #       in jonadabot_triggers.pl as a hash of coderefs or somesuch; it should
    #       then be possible to reload jonadabot_triggers.pl without restarting.
    say(vladsbane(), channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
  } elsif ($text =~ /^!members?\s*(\w*)\s*(\w*)/) {
    my ($subcommand, $target) = ($1, $2);
    $subcommand ||= 'list';
    if ($irc{okdom}{$howtorespond}) {
      if ($subcommand eq 'list') {
        # TODO: purge $irc{demi} (or convert it into purely a cache) and use a database table.
        say((join " ", @{$irc{demi}}),
            channel => $howtorespond, sender => $sender, fallbackto => 'private');
      } elsif ($subcommand eq 'add') {
        push @{$irc{demi}}, $target;
        %demilichen = map {
          my $dl = $_;
          ($dl => 1, (lc $dl) => 1)
        } @{$irc{demi}};
        say("Added $target to my list of $irc{clan}",
            channel => $howtorespond, sender => $sender, fallbackto => 'private');
      } elsif ($subcommand eq 'subtract') {
        $irc{demi} = [grep { $_ ne $target } @{$irc{demi}}];
        %demilichen = map {
          my $dl = $_;
          ($dl => 1, (lc $dl) => 1)
        } @{$irc{demi}};
        say("Removed $target from my list of $irc{clan}",
            channel => $howtorespond, sender => $sender, fallbackto => 'private');
      }}
  } elsif ($text =~ /^!anthem/) { # TODO: generalize this in the same way as !trophies and !deaths
    my $anthemfile = qq[nethack-$irc{clan}-anthem.png];
    if (-e ('/var/www/nethack-stuff/' . $anthemfile)) {
      say("http://74.135.83.0:8018/nethack-stuff/$anthemfile",
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
    }
  } elsif ($text =~ /^!gt\s*(.*)/) {
    my ($member) = ($1);
    %demilichen = map {
          my $dl = $_;
          ($dl => 1, (lc $dl) => 1)
        } @{$irc{demi}};
    if ($demilichen{$member}) { # TODO: use ganbatte()
      my $whoever = join " ", map { ucfirst lc $_ } split /\s+/, $member;
      say("Go $whoever!",
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
    } else {
      my $teamname = ucfirst $irc{clan};
      say("Go Team $teamname!",
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
    }
  } elsif ($text =~ /^!(rng|role|race)\s*(.*)/) { # TODO: handle this out of the generalized triggers interface
    my ($command, $stuff) = ($1, $2);
    if ($irc{okdom}{$howtorespond}) {
      my @item;
      my %special = (
                     role => [qw(Val Val Val Val Val Val Val
                                 Sam Sam Sam Sam Sam
                                 Arc Bar Cav Hea Kni Mon Pri Ran
                                 Rog Tou Tou Wiz )],
                     race => [qw(Human Human Human Human
                                 Dwarf Dwarf Elf Elf
                                 Gnome Gnome Gnome Orc)],
                    );
      if ($special{lc $command}) {
        @item = @{$special{lc $command}};
      } elsif ($stuff =~ /[@](\w+)/) {
        my $arrayname = lc $1;
        if ($special{$arrayname}) {
          @item = @{$special{$arrayname}};
        }
      }
      if (@item) {
        # Already did that.
      } elsif ($stuff =~ m![|]!) {
        @item = map { s/^\s*//; s/\s*$//; $_ } split /[|]/, $stuff;
      } elsif ($stuff =~ /,/) {
        @item = map { s/^\s*//; s/\s*$//; $_  } split /,/, $stuff;
      } else {
        @item = split /\s+/, $stuff;
      }
      my $item = $item[rand @item];
      say($item,
          channel => $howtorespond, sender => $sender, fallbackto => 'private');
    }
  } elsif ($text =~ /^!showpref\s*(\w+)/) {
    my ($var) = ($1);
    my $value = getircuserpref($sender, $var);
    say("$var == $value", channel => 'private', sender => $sender);
  } elsif ($text =~ /^!set\s*(\w+)\s+(.*)/) {
    # TODO: add a list of valid pref variable names to the database and support setting values for any pref listed there.
    #       but note that for security reasons timezone needs to remain special-cased.
    # TODO: support /listing/ your own set prefs (by /msg only, not in channel).
    my ($var, $value) = ($1, $2);
    chomp $value; # Not sure if this is necessary.
    logit("$sender wants to set $var preference to $value") if $debug{preference};
    if ($var eq 'timezone') {
      my ($tz) = $value =~ m!(\w+(?:[/]\w+)*)!;
      logit("potential timezone value: $tz") if $debug{preference} > 1;
      my ($tzname) = grep { $_ eq $tz } DateTime::TimeZone->all_names();
      $tzname ||= $prefdefault{timezone};
      setircuserpref($sender, $var, $value, channel => ($irc{okdom}{$howtorespond} ? $howtorespond : 'private'));
    } elsif ($var eq '') {
      my $tz = getircuserpref($sender, 'timezone');
      say('timezone: $tz',
          channel => $howtorespond, sender => $sender, fallbackto => 'private') if $irc{okdom}{$howtorespond};
    }
  } elsif ($text =~ /^!message (\d+)/) {
    viewmessage(number => $1, channel => $howtorespond, sender => $sender, fallbackto => 'private');
  } elsif ($text =~ /^!tell (\w+)\s*(.*)/) {
    my ($target, $msg) = ($1, $2);
    my $result = addrecord('memorandum', +{
                                           sender  => $sender,
                                           channel => $howtorespond,
                                           target  => $target,
                                           thedate => DateTime::Format::ForDB(DateTime->now(@tz)),
                                           message => $msg,
                                          });
    my $id = $db::added_record_id;
    if ($id) {
      my $r = getrecord('memorandum', $id);
      if ($$r{message} eq $msg) {
        say("Ok, $$r{sender}, I'll let $$r{target} know.",
            channel => $howtorespond, sender => $sender, fallbackto => 'private' );
      } else {
        say("Oh, dear, something seems to be wrong with my message storage facility.",
            channel => $howtorespond, sender => $sender, fallbackto => 'private', );
      }
    } else {
      say("Hmm... something seems to be wrong with my message storage facility.",
          channel => $howtorespond, sender => $sender, fallbackto => 'private', );
    }
  } elsif ($text =~ /^!seen (.*)/) {
    my ($whoever) = ($1);
    #my $when = $irc{channel}{lc ($wherever || $howtorespond)}{seen}{lc $whoever};
    #my $where = $wherever ? "in $wherever" : "here";
    my $answer = "/me has not seen $whoever lately.";
    my @s = findrecord('seen', nick => $whoever);
    my %self = map { $_ => 1 } @{$irc{nick}};
    if ($self{$whoever}) {
      $answer = "Hi, $sender.";
      $fallbacktoprivate = 1;
    } elsif (@s) {
      my $s = $s[0];
      $answer = "/me last saw $$s{nick} in $$s{channel} "
        . friendlytime(DateTime::Format::MySQL->parse_datetime($$s{whenseen}),
                       getircuserpref($sender, 'timezone')) . ".";
    }
    if (($howtorespond eq 'private') or ($irc{okdom}{$howtorespond})) {
      say($answer, channel => $howtorespond, sender => $sender, fallbackto => 'private'  );
    } elsif ($irc{master}{$sender} or $fallbacktoprivate) {
      #$answer =~ s/\bhere\b/in $howtorespond/;
      say($answer, channel => 'private', sender => $sender, fallbackto => 'private' );
    }
  } elsif ($text =~ /^!(time|date)/) {
    # TODO:  allow the user to specify a timezone (but be careful about security issues).
    my $date = friendlytime(DateTime->now(@tz), getircuserpref($sender, 'timezone'), 'announce');
    say ($date, channel => $howtorespond, sender => $sender, fallbackto => 'private');
  } elsif ($text =~ /^!rot13/i) {
    my ($blah) = $text =~ /^!rot13\s*(.*)/i;
    $blah =~ tr/A-Za-z/N-ZA-Mn-za-m/;
    say("!ebg13 $blah", channel => $howtorespond, sender => $sender, fallbackto => 'private');
  } elsif ($text =~ /^!alarm/i) {
    logit($text) if $debug{alarm};
    say("Hmm...", channel => 'private', sender => $sender) if $debug{alarm} > 6;
    # TODO: document this feature in !help
    if ($text =~ m~^!alarm set (.+)~i) {
      my ($setparams) = ($1);
      logit("Alarm: $sender wants to set $setparams") if $debug{alarm};
      if ($setparams =~ m~(today|tomorrow|Sun|Mon|Tue|Wed|Thu|Fri|Sat|(?:\d*[-]?\s*(?:the|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|)(?:[a-z]*)\s*\d+(?:st|nd|rd)?))\s*(?:at)?\s*(\d+[:]?\d*[:]?\d*\s*(?:am|pm)?)\s*(.*)~i) {
        my ($datepart, $timepart, $message) = ($1, $2, $3);
        if ($debug{alarm} > 3) {
          logit("datepart: $datepart", 3);
          logit("timepart: $timepart", 3);
          logit("message:  $message",  3);
        }
        my $tz = (getircuserpref($sender, 'timezone') || $prefdefault{timezone} || $servertz);
        logit("timezone: $tz") if ($debug{timezone} + $debug{alarm} > 4);
        my $thedate = DateTime->now( time_zone => $tz);
        logit("default date: " . $thedate->ymd(), 2) if $debug{alarm} > 6;
        if ($datepart =~ /tomorrow/) {
          $thedate = $thedate->add( days => 1 );
          logit("tomorrow: " . $thedate->ymd(), 2) if $debug{alarm} > 3;
        } elsif ($datepart =~ /(Sun|Mon|Tue|Wed|Thu|Fri|Sat)/i) {
          my $dow = $1;
          while ($thedate->day_abbr ne ucfirst lc $dow) {
            $thedate = $thedate->add( days => 1 );
          }
          logit("Day of Week ($dow): " . $thedate->day_abbr() . " " . $thedate->ymd(), 2) if $debug{alarm} > 3;
        } elsif ($datepart =~ /(\d*)[-]?\s*(The|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)?(?:[a-z]*)\s*(\d+)(?:st|nd|rd)?/i) {
          my ($yr, $mo, $md) = ($1, $2, $3);
          logit("yr $yr, mo $mo, md $md", 3) if $debug{alarm} > 3;
          $yr ||= $thedate->year();
          my %monum = ( Jan => 1,  Feb => 2, Mar => 3, Apr =>  4, May =>  5, Jun =>  6,
                        Jul => 7,  Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12, );
          my $month = $monum{ucfirst lc $mo} || $thedate->month();
          logit("yr $yr, month $month, md $md", 4) if $debug{alarm} > 3;
          $thedate = DateTime->new( year => $yr, month => $month, day => $md, time_zone => $tz);
        }
        logit("thedate: " . $thedate->ymd(), 3) if $debug{alarm} > 3;
        $timepart =~ m~(\d+)[:]?(\d*)[:]?(\d*)\s*(am|pm|)~i;
        my ($hr, $mn, $sc, $ampm) = ($1, $2, $3, $4);
        if ($ampm eq 'pm') {
          $hr += 12 unless $hr > 11;
        } elsif ($ampm eq 'am') {
          $hr = $hr % 12;
        }
        logit("hr $hr, mn $mn, sc $sc", 3) if $debug{alarm} > 4;
        my $dt = DateTime->new( year => $thedate->year(), month => $thedate->month(), day => $thedate->mday(),
                                hour => $hr, minute => ($mn || 0), second => ($sc || 0), time_zone => $tz);
        logit("dt " . $dt->ymd() . " at " . $dt->hms(), 3) if $debug{alarm} > 2;
        $message ||= "It's " . friendlytime($dt) . "!";
        setalarm($dt, $message, channel => $howtorespond, sender => $sender, fallbackto => 'private');
      } else {
        say("Sorry, I did not understand that date and time.", channel => 'private', sender => $sender);
      }
    } elsif ($text =~ /!alarm snooze/i) {
      #TODO
    } elsif ($text =~ /!alarm (\d+)\s*(.*)/) {
      my ($num, $rest) = ($1, $2);
      my $alarm = getrecord('alarm', $num);
      if (not $alarm) {
        say("No such alarm: $num", channel => 'private', sender => $sender);
      } elsif (lc($$alarm{nick}) ne lc $sender) {
        say("Not your alarm: $num", channel => 'private', sender => $sender);
      } else {
        my $forwhen = friendlytime(DateTime::Format::MySQL->parse_datetime($$alarm{snoozetill} || $$alarm{alarmdate}),
                                   getircuserpref($sender, 'timezone') || $prefdefault{timezone} || $servertz);
        say("Alarm $$alarm{id} viewed " . ($$alarm{viewcount} || 0) . " time(s), "
            . ($$alarm{status} ? 'inactive' : "set to go off $forwhen") . ".",
            channel => 'private', sender => $sender);
        my $willsay = $alarm{status} ? "said" : "will say";
        say(qq[Alarm $willsay "$$alarm{message}".], channel => 'private', sender => $sender);
      }
    } elsif ($text =~ /!alarms\s*(.*)/) {
      my @extraarg = split /\s+/, $1;
      my @alarm = findrecord('alarm', 'nick', $sender);
      if (grep { /inactive/ } @extraarg) {
        @alarm = grep { $$_{status} } @alarm;
      } else {
        @alarm = grep { not $$_{status} } @alarm;
      }
      my $dbnow = DateTime::Format::ForDB(DateTime->now(@tz));
      if (grep { /future/ } @extraarg ) {
        @alarm = grep { $$_{alarmdate} ge $dbnow } @alarm;
      } elsif (grep { /past/ } @extraarg) {
        @alarm = grep { $$_{alarmdate} le $dbnow } @alarm;
      }
      if (0 >= scalar @alarm) {
        say("You currently have no " . (@extraarg ? "(@extraarg) " : '') . "alarms set.",
            channel => 'private', sender => $sender);
      } elsif (1 == scalar @alarm) {
        my $alarm = $alarm[0];
        my $forwhen = friendlytime(DateTime::Format::MySQL->parse_datetime($$alarm{snoozetill} || $$alarm{alarmdate}),
                                   getircuserpref($sender, 'timezone') || $prefdefault{timezone} || $servertz);
        say("Alarm $$alarm{id} set to go off $forwhen.", channel => 'private', sender => $sender);
      } else {
        say("" . @alarm . " alarms: " . (join ", ", map { $$_{id} } @alarm),
            channel => 'private', sender => $sender);
      }
    }
  } elsif (((($text =~ /Ars[ie]no|$irc{nick}|jonadabot/i) or ($howtorespond eq 'private')) and
           (($text =~ /are(?:n't)? you (a|an|the|human|\w*bot|puppet)/i) or ($text =~ /(who|what) are you/i)
            or ($text =~ /(who|what) is (Ars[ie]no|jonadabot)/i)))
           or ($text =~ /^!about/)) {
    my $size = 0; $size += $_ for map { -s $_ } $0, $guts, $utilsubs, $extrasubs, $regexen, $teacode, $dbcode, $watchlog ;
    say("/me is a Perl script, $devname version $version, $size bytes, see also $gitpage",
        channel => $howtorespond, sender => $sender, fallbackto => 'private' );
    say("I was originally written by $author and am currently operated by $irc{oper}, who frequents this same network.",
        channel => $howtorespond, sender => $sender, fallbackto => 'private' );
  } elsif ($text =~ /Ars[ie]no.*(pretty|nice|lovely|cute)\s+name/i) {
    say("Thank you.", channel => $howtorespond, sender => $sender, fallbackto => 'private'  );
  } elsif ($text =~ /^Xyzzy/i and (($howtorespond eq 'private') or (12 > rand(100)))) {
    my @msg = ("You are inside a building, a well house for a large spring.",
               "You are in a debris room filled with stuff washed in from the surface.",);
    say($msg[int rand @msg], channel => $howtorespond, sender => $sender );
  } elsif ($text =~ /^!help\s*(.*)/) {
    say(helpinfo($1), channel => $howtorespond, sender => $sender, fallbackto => 'private');
  } elsif ($text =~ /^!say\s*to\s*(\S+)\s*(.+)/) {
    my ($target, $thing) = ($1, $2);
    if ($irc{master}{$sender}) {
      if ($target =~ /^[#]/) {
        say($thing, channel => $target, sender => $sender, fallbackto =>'private');
      } else {
        say($thing, channel => 'private', sender => $sender);
      }
    } else {
      say("Tell them yourself, $sender", channel => 'private', sender => $sender);
    }
  } elsif ($text =~ /^!debug (.*)/ and $irc{master}{$sender}) {
    say(debuginfo($1), channel => 'private', sender => $sender );
  } elsif ($text =~ /^!email\s+(\w+)\s*(\S.*?)\s*[:]\s*(.+)/) {
    my ($mnemonic, $subject, $restofmessage) = ($1, $2, $3);
    my $contact = findrecord("emailcontact", "ircnick", $sender, "mnemonic", $mnemonic);
    if ($contact) {
      my $body = $subject . $restofmessage . ($$contact{signature} || "\n --$sender\n");
      my $from = getconfigvar($cfgprofile, 'operatoremailaddress'); # TODO: allow the operator to establish different from fields for different users.
      my $dest = getrecord("emaildest", $$contact{emaildest});
      my $result = addrecord("mailqueue", +{ tofield   => $$dest{address},
                                             fromfield => $from,
                                             nick      => $sender,
                                             subject   => $subject,
                                             body      => $body,
                                             bcc       => $$dest{bcc},
                                             enqueued  => DateTime::Format::ForDB(DateTime->now(@tz)),
                                           });
      if ($result) {
        say("Message enqueued (" . $db::added_record_id . ")", channel => 'private', sender => $sender);
      } else {
        logit("Failed to enqueue email message ($text)");
        say("Failed to enqueue your message, sorry.", channel => 'private', sender => $sender);
      }
    } else {
      say("Email contact not found: $mnemonic (for $sender)", channel => 'private', sender => $sender);
    }
  } elsif ($text =~ /^!sms (\w+) (.*)/) {
    my ($target, $msg) = ($1, $2);
    my $mrec = findrecord("smsmnemonic", ircnick => $sender, mnemonic => $target);
    if (ref $mrec) {
      my $dest = getrecord("smsdestination", $$mrec{destination});
      if ($dest) {
        my $carrier = getrecord("smscarrier", $$dest{carrier});
        if ($carrier) {
          my $gateway = findrecord("smscarriergate", "carrier", $$carrier{id}); # TODO: support multiple gateways per carrier in a reasonable way
          if ($gateway) {
            my $address = $$dest{phnumber} . '@' . $$gateway{domain};
            my $smtp    = getrecord('smtp'); # TODO: support multiple smtp servers in some way.
            if (ref $smtp) {
              my $from = getconfigvar($cfgprofile, 'ircemailaddress'); # TODO: allow the operator to set up per-user from fields, with this being just the default
              if ($from) {
                my $subject;
                if ($msg =~ /^(.*?)[[](.*?)[]](.*)$/) {
                  my ($pre, $subj, $post) = ($1, $2, $3);
                  $subject = join ' ', map { ucfirst lc $_ } split /\s+/, $subj;
                } else {
                  $subject = $msg;
                }
                my $result = addrecord("mailqueue", +{
                                                      tofield    => $address,
                                                      fromfield  => $from,
                                                      body       => $msg,
                                                      nick       => $sender,
                                                      bcc        => $$smtp{bcc}, # this is allowed to be undef
                                                      subject    => $subject,
                                                      enqueued   => DateTime::Format::ForDB(DateTime->now(@tz)),
                                                     });
                if ($result) {
                  say("Enqueued mail #" . $db::added_record_id . " to $address",
                      channel => 'private', sender => $sender );
                } else {
                  say("Enqueing mail to $address seems to have failed.",
                      channel => 'private', sender => $sender );
                }
              } else {
                say("No from field; $irc{oper} needs to configure ircemailaddress.",
                    channel => 'private', sender => $sender );
              }
            } else {
              say("No smtp server; $irc{oper} needs to configure one.",
                  channel => 'private', sender => $sender );
            }
          } else {
            say("No email-to-SMS gateway configured for cellular carrier $$carrier{id}.", # TODO: better field
                channel => 'private', sender => $sender );
          }
        } else {
          say("Could not find cellular carrier number $$dest{carrier} in my database.",
              channel => 'private', sender => $sender );
        }
      } else {
        say("No cellphone number on file for $$mrec{mnemonic}, sorry.",
            channel => 'private', sender => $sender );
      }
    } else {
      say("No SMS contact info on file for $target, sorry.",
          channel => 'private', sender => $sender );
    }
  } elsif ($text =~ /^!biff/) {
    logit("!biff command from $sender: $text") if $debug{biff} > 1;
    warn "!biff: no sender means no ownernick" if not $sender;
    my @box = findrecord("popbox", "ownernick", $sender);
    my %box = map { $$_{mnemonic} => $_ } @box;
    if ($text =~ /^!biff reset/) {
      logit("Doing !biff reset for $sender (" . @box . " mailboxes)") if $debug{biff};
      for my $box (@box) {
        $$box{count} = 0;
        updaterecord("popbox", $box);
      }
    } elsif ($text =~ /^!biff list/) { # list accounts
      logit("Listing mailboxes for $sender") if $debug{biff};
      if (@box) {
        say(("Your POP3 mailboxes: " . join ", ", map { $$_{mnemonic} } @box),
            channel => 'private', sender => $sender );
      } else {
        say("No POP3 mailboxes for $sender", channel => 'private', sender => $sender);
      }
    } elsif ($text =~ /^!biff reload/ and $irc{master}{$sender}) {
      logit("Attempting !biff reload at request of $sender");
      do "jonadabot_regexes.pl";
      # TODO: also reload the account info from the database.  Or, better, do that when it's used.
      say("Reloaded watch regexes.", channel => 'private', sender => $sender);
    } elsif ($text =~ /!biff (\w+)/ and ($box{$1})) {
      my $popbox = $1;
      logit("!biff request for box $popbox", 3) if $debug{biff} > 1;
      if ($text =~ /!biff $popbox (\d+)\s*(.*)/) {
        my ($msgnum, $therest) = ($1, $2);
        logit("request is for message $msgnum", 4) if $debug{biff} > 2;
        my (@field) = split /\s+/, $therest;
        push @field, 'Subject' if not @field;
        for my $field (grep { $_ ne uc $_ } @field) { # mixed-case fields are header fields
          for my $msg (biffhelper($popbox, $msgnum, [$field], 'suppresswatch', $sender, 'handlemessage (box-specific)')) {
            say($msg, channel => 'private', sender => $sender);
            select undef,undef,undef,0.2;
          }
        } # TODO: make biffhelper support this stuff too, get rid of the grep, and simplify.
        if (grep { $_ eq uc $_ } @field) {
          # All-uppercase fields are magic.
          warn "!biff (position 2): No sender means no ownernick" if not $sender;
          my @pbr = findrecord('popbox',
                               ownernick => $sender,
                               (($popbox =~ /^\d+$/) ? 'id' : 'mnemonic') => $popbox, );
          if (scalar @pbr) {
            my @server = getrecord('popserver', $pbr[0]{server});
            if (scalar @server) {
              my $pop = new Mail::POP3Client( USER      => $pbr[0]{popuser},
                                              PASSWORD  => $pbr[0]{poppass},
                                              HOST      => $server[0]{serveraddress});
              my $count = $pop->Count();
              logit("POP3 Count: $count ($popbox => $pbr[0]{popuser} on $server[0]{serveraddress}) [A]") if $debug{pop3} > 1;
              if (grep { $_ eq 'SIZE' } @field) {
                my $body = $pop->Body($msgnum);
                my $size = length($body);
                say($size . " bytes", channel => 'private', sender => $sender );
              } elsif (grep { /^(BODY|LINES)$/ } @field) {
                my @line = $pop->Body($msgnum);
                if (grep { $_ eq 'LINES' } @field) {
                  say("" . @line . " lines", channel => 'private', sender => $sender );
                }
                if (grep { $_ eq 'BODY' } @field) {
                  if ($irc{maxlines} >= scalar @line) {
                    for my $l (@line) {
                      chomp $l;
                      say($l, channel => 'private', sender => $sender );
                      select undef, undef, undef, (0.2 * scalar @line);
                    }
                  } else {
                    say("Too many lines (" . @line . ")", channel => 'private', sender => $sender );
                  }
                }
              }
            } else {
              say("Configuration error: no POP3 server for mailbox '$popbox'.",
                  channel => 'private', sender => $sender );
            }
          } else {
            say("Either I have no record of POP3 inbox '$popbox', or it does not belong to you, $sender.",
                channel => 'private', sender => $sender );
          }
        }
      } else {
        my $count   = biffhelper($popbox, undef, ['COUNT']);
        say("$count messages waiting in $popbox", channel => 'private', sender => $sender, 'handlemessage (getting count)');
      }
    } elsif ($irc{master}{$sender}) {
      # TODO: audit biff() to ensure they can only get their own mail,
      # then remove the master requirement here.
      logit("That's a general biff check request from $sender", 3) if $debug{biff} > 2;
      biff($sender, 'saycount');
    }
  } elsif ($text =~ /^!notifications/ and $irc{master}{$sender}) {
    my $n = scalar @notification;
    say(qq[$n notification(s) pending], channel => 'private', sender => $sender);
    processnotification();
  } elsif ($text =~ /^backscroll\s*([#]+\S+)/) {
    # TODO:  answer !backscroll [channel] [number] [timeunit|lines]
    # (The intention here is to allow a person who just connected to get what they missed.)
    # (The bot could collect the info itself or use an irssi logfile if one is available.)
    # (It would only ever be sent via private /msg of course.)
    say(qq[Yeah, $devname has been meaning to implement a !backscroll command...],
        channel => 'private', sender => $sender);
  } elsif ($text =~ /^!shutdown/ and $irc{master}{$sender}) {
    # TODO: implement this.  Just doing exit 0 does not work, because of AnyEvent.
    #  logit("Shutdown at the request of $sender", 1);
    # TODO: might also be good to implement a disconnect/reconnect,
    #       perhaps in conjunction with multi-irc-network support for version 007 or 008.
  } elsif ($text =~ /^!nick\s*(\w+)/ and $irc{master}{$sender}) {
    my ($nick) = $1;
    my %isnick = map { $_ => 1 } (getconfigvar($cfgprofile, 'ircnick'), $defaultusername);
    if (($irc{master}{$sender} or getconfigvar($cfgprofile, 'allownicktrigger'))
        and $isnick{$nick}) {
      logit("/nick $nick at the request of $sender");
      $irc->send_srv( NICK => $nick );
    }
  } elsif ($text =~ /^!join ([#]+\w+(?:[-]\w+)*)/ and $irc{master}{$sender}) {
    my ($ch) = ($1);
    logit("Attempting to /join $ch at the request of $sender");
    $irc->send_srv( JOIN => $ch );
    $irc{channel}{$ch} ||= +{};
  } elsif ($text =~ /^!part ([#]+\w+(?:[-]\w+)*)/ and $irc{master}{$sender}) {
    my ($ch) = ($1);
    logit("Attempting to /part $ch at the request of $sender");
    $irc->send_srv( PART => $ch );
    delete $irc{channel}{$ch};
  } elsif ($text =~ /^!reload/ and $irc{master}{$sender}) {
    $|=1;
    if ($text =~ /^!reload full/i) { # TODO: Test that this actually works.
      logit("FULL reload at the request of $sender", 1);
      exec "perl", $0;
      logit("exec returned (!reload)", 1);
      system("kill", $$);
      exit 2;
    } else { # TODO: re-test how well this works in 006, and clean up any non-working bits.
      logit("Reloading components at the request of $sender", 1);
      do $dbcode;
      do $guts;
      do $biffvars;
      do $teacode;
      %demilichen = map {
        my $dl = $_;
        ($dl => 1, (lc $dl) => 1)
      } @{$irc{demi}};
      do $watchrod;
      logit("Reload complete.", 1);
    }
  } elsif ($text =~ /^!(\w+)/ and (@rec = findrecord("bottrigger", "bottrigger", $1, "enabled", 1))) {
    logit("Can't Happen: no bottrigger record for $text") if not @rec;
    for my $t (@rec) {
      if ((not $$t{channel}) or (index($$t{channel}, $howtorespond) > 0) or ($howtorespond eq 'private')) {
        if (($irc{okdom}{$howtorespond}) or (not ($$t{flags} =~ /C/))
            or ($howtorespond eq 'private')) { # C means respond in channel even if not okdom
          if ($irc{master}{$sender} or not $$t{flags} =~ /M/) { # M means master-only bottrigger
            if ($$t{flags} =~ /R/) { # R means Routine bottrigger, as opposed to flat text
              if ($routine{$$t{answer}}) {
                my $response = $routine{$$t{answer}}->($$t{bottrigger}, channel => $howtorespond, text => $text);
                # TODO: pass more args there to allow routines more flexibility in what they can do.
                if ($response) {
                  say($response, channel => $howtorespond, sender => $sender, fallbackto => 'private')
                } else {
                  logit("No response from routine $$t{answer} for bottrigger $$t{bottrigger}"); # always log this; it's an error
                }
              } else {
                logit("Did not find routine $$t{answer} for bottrigger $$t{bottrigger}"); # always log this; it's an error
              }
            } else {
              # Flat, non-routine bottrigger
              say($$t{answer}, channel => $howtorespond, sender => $sender, fallbackto => 'private');
            }
          } else {
            logit("Not responding to master-only custom bottrigger in channel $howtorespond for sender $sender") if $debug{bottrigger};
          }
        } else {
          logit("Not responding to custom bottrigger $$t{bottrigger} in non-okdom channel $howtorespond") if $debug{bottrigger};
        }
      } else {
        logit("Not responding to custom bottrigger $$t{bottrigger} in non-included channel $howtorespond") if $debug{bottrigger};
      }
    }
  } elsif ($irc{echo}{$sender}{$howtorespond}{count}) { # Answers from triggers that we proxied to other bots:
    my $fallback = shift @{$irc{echo}{$sender}{$howtorespond}{fallback}};
    for my $chan (@{$irc{echo}{$sender}{$howtorespond}{channels}}) {
      say(qq[$sender says: $text], channel => $chan, sender => $fallback, fallbackto => 'private');
    }
  }
  # Finally, check to see if we have any memoranda for the person who just spoke:
  my @msg = grep { not $$_{status} } findrecord('memorandum', 'target', $sender);
  if (scalar @msg) {
    if (2 < scalar @msg) {
      my $nums = commalist(map { $$_{id} } @msg);
      say("$sender, I have " . @msg . " new messages for you (numbers $nums).  Use !message [number] to view them.",
          channel => $howtorespond, sender => $sender, fallbackto => 'private');
    } else {
      for my $num (map { $$_{id} } @msg) {
        viewmessage(number => $num, channel => $howtorespond, sender => $sender, fallbackto => 'private');
      }
    }
  } elsif ($sender and $irc{master}{$sender} and scalar @notification) {
    processnotification();
  } else {
    # Don't do anything here that takes a lot of time.  It would cause really slow startup
    # as all the server notices are processed.
  }
}

sub haveseenlately {
  my ($nick) = @_;
  # Check to see if we've seen that user "lately".
  my ($latelynum, $latelyunit) = ("" . getconfigvar($cfgprofile, 'lately') || "72 hours")
    =~ /([0-9.]+)\s*(second|minute|hour|day|week|month|year)/; # We stop short of the "s" here, add it below, so it's optional.
  $latelyunit ||= 'minute';
  my $lately = DateTime::Format::ForDB(DateTime->now(@tz)->add( ($latelyunit . "s") => $latelynum ));
  my @seen = sort { $$b{whenseen} cmp $$a{whenseen} } grep { $$_{whenseen} ge $lately } findrecord('seen', nick => $namedrecipient);
  return if not scalar @seen;
  return $seen[0];
}

sub viewmessage {
  my (%arg) = @_;
  my $r = getrecord('memorandum', $arg{number});
  if ($$r{target} eq $arg{sender}) {
    my $dt = DateTime::Format::FromDB($$r{thedate});
    my $date = friendlytime($dt, getircuserpref($$r{target}, 'timezone') || $prefdefault{timezone} || $servertz);
    say(qq[$sender: $$r{sender} says, $$r{message} (in $$r{channel}, $date)], %arg);
    $$r{status} = 2;
    $$r{statusdate} = DateTime::Format::ForDB(DateTime->now(@tz));
    updaterecord('memorandum', $r);
  } else {
    say("$sender, that message is for $$r{target}.", %arg);
  }
}

#sub ircmessage { # This was a debugging aid.  Is it still called anywhere?
#  my ($msg) = @_;
#  my %m = map {
#    $_ => '' . $$msg{$_} . '',
#  } keys %$msg;
#  return \%m;
#}

sub ampmtime {
  my ($when) = @_;
  # TODO:  say "Noon" or "Midnight" when appropriate.
  my $hour   = ($when->hour() % 12) || 12;
  my $minute = $when->minute();
  my $ampm   = '';
  my $now    = DateTime->now(@tz);
  if (($when->clone()->add(hours => 12) > $now)
      or ($now->add(hours => 12) > $when)) {
    $ampm = ($when->hour >= 12) ? 'pm' : 'am';
  }
  return $hour . ":" . (sprintf "%02d", $minute) . $ampm;
}

sub friendlytime { # TODO: make some parts of this customizable via userpref, beyond just the timezone.
  my ($whendt, $displaytz, $style) = @_;
  my $when = $whendt->clone();
  $displaytz ||= $prefdefault{timezone} || $servertz;
  $when->set_time_zone($displaytz);
  my $now = DateTime->now( @tz )->set_time_zone($displaytz);
  if ($style eq 'announce') {
    return "It is now " . $when->day_name() . ", " . $when->year()
      . ' ' . $when->month_name() . ' ' . $when->mday() . " at " . ampmtime($when)
      . " " . friendlytz($when);
  } elsif (($when->ymd() eq $now->ymd())
      or ($when->clone()->add(hours => 12) > $now)) {
    return "at " . ampmtime($when) . " " . friendlytz($when);
  } elsif ($when->clone()->add( days => 5 ) > $now) {
    return "on " . $when->day_name() . " at " . ampmtime($when) . " " . friendlytz($when);
  } else {
    return "on " . $when->ymd() . ".";
  }
}

sub friendlytz {
  my ($dt) = @_;
  my $tzone = $dt->time_zone();
  my $kludge          = $dt->time_zone_short_name() || $tzone;
  my ($nodst, $isdst) = @{ $friendlytzname{$tzone} || [$kludge, $kludge] };
  return ($dt->is_dst()) ? $isdst: $nodst;
}

sub biffhelper {
  my ($popbox, $msgnum, $fields, $suppresswatch, $ownernick, $caller) = @_;
  warn "biffhelper: no ownernick (from $caller)" if not $ownernick;
  my @answer;
  $fields ||= $msgnum ? ['Subject'] : ['COUNT'];
  for my $field (@$fields) {
    my @pbr = findrecord('popbox', (($popbox =~ /^\d+$/) ? 'id' : 'mnemonic') => $popbox );
    @pbr = grep { $$_{ownernick} eq $ownernick } @pbr if $ownernick;
    if (scalar @pbr) {
      my @server = getrecord('popserver', $pbr[0]{server});
      if (scalar @server) {
        my @bwargs;
        my $pop = new Mail::POP3Client( USER     => $pbr[0]{popuser},
                                        PASSWORD => $pbr[0]{poppass},
                                        HOST     => $server[0]{serveraddress});
        my $oldcount = $pbr[0]{count} || 0;
        my $count = $pop->Count();
        logit("POP3 Count: $count ($popbox => $pbr[0]{popuser} on $server[0]{serveraddress}) [BH]") if $debug{pop3} > 1;
        if ($field eq 'COUNT') {
          push @answer, $count;
        } elsif ($field eq 'SIZE') {
          my $body = $pop->Body($msgnum);
          my $size = length($body);
          $answer = $size . " bytes";
        } elsif ($field =~ /^(LINES|BODY)$/) { # TODO
          my @line = $pop->Body($msgnum);
          if ($field eq 'LINES') {
            my $lc = scalar @line;
            push @answer, qq[$lc lines];
          } else {
            if ($irc{maxlines} >= scalar @line) {
              for my $l (@line) {
                chomp $l;
                push @answer, $l;
              }
            } else {
              push @answer, "Too many lines ($lc).";
            }
          }
        } elsif ($field ne uc $field) { # mixed-case fields are header fields
          if ($msgnum) {
            my @h = grep { /^$field/ } $pop->Head($msgnum);
            if (scalar @h) {
              if ($irc{maxlines} >= scalar @h) {
                push @answer, $_ for @h;
              } else {
                push @answer, "Too many $field fields for message $msgnum ($popbox).";
              }
            } else {
              push @answer, "No $field header for message $msgnum ($popbox).";
            }
          } else {
            logit("biffhelper:  cannot get $field header field without message number ($popbox).");
          }
        }
        if (not $suppresswatch) {
          logit("biffhelper: checking need to watch $popbox", 3) if $debug{biff} >= 3;
          if ($count == 0) {
            logit("biffhelper: no mail to watch ($popbox)", 4) if $debug{biff} >= 4;
          } elsif ($count <= $oldcount) {
            logit("biffhelper: user must have got their mail ($popbox)", 4) if $debug{biff} >= 4;
            logit("[count: $count; already know about $oldcount].", 5) if $debug{biff} >= 5;
            $pbr[0]{count} = $count;
            updaterecord('popbox', $pbr[0]);
          } elsif ($count > $oldcount) {
            my $n = $count - $oldcount;
            logit("biffhelper: need to watch $n messages ($popbox)", 4) if $debug{biff} >= 4;
            for my $i (($oldcount + 1) .. $count) {
              my @h = $pop->Head($i);
              logit("biffhelper: found " . @h . " headers to watch", 5) if $debug{biff} >= 5;
              for my $w (map { $$_{watchkey}} findrecord('popwatch', 'popbox', $pbr[0]{id})) {
                push @bwargs, [$popbox, $w, [@h], $i];
              }
              $pbr[0]{count}++;
            }
            updaterecord('popbox', $pbr[0]);
          }}
        $pop->close(); # necessary because POP3 servers don't necessarily allow simultaneous connections.
        # TODO: don't close; instead pass the $pop object to biffwatch() and re-use it; that would be more robust anyway.
        for my $args (@bwargs) {
          biffwatch(@$args);
        }
        push @answer, $count;
      } else {
        logit("Error: no server address record for popbox $popbox");
      }
    } else {
      logit("ERROR: no popbox record for $popbox");
    }
  }
  if (wantarray) {
    return @answer;
  } else {
    return $answer[0];
  }
}

sub biff {
  my ($owner, $saycount) = @_;
  my $total = 0;
  logit("biff($owner, $saycount)", 4) if $debug{biff} > 2;
  warn "biff(): no owner specified, defaulting to $irc{oper}" if not $owner;
  $owner ||= $irc{oper};
  warn "biff(): no owner/operator" and return if not $owner;
  my @confkey = map { $$_{mnemonic} } findrecord("popbox", "ownernick", $owner);
  for my $confkey (@confkey) {
    logit("Biff: checking POP3: $confkey", 2);
    my $count = biffhelper($confkey, undef, undef, undef, $owner, 'biff');
    logit("Count for $confkey: $count") if $debug{biff} > 3;
    $total += $count;
    logit("Biff Count: $count ($confkey)") if $debug{pop3} > 1;
  }
  if ($saycount) {
    logit("Biff count total for $owner: $total") if $debug{biff} > 4;
    say("Total of $total messages in " . @confkey . " POP3 account(s).",
        channel => 'private', sender => $owner);
  }
}

sub biffwatch { # TODO:  unwrap wrapped header lines before processing.
  # TODO:  allow the same bot to watch mail for and notify multiple users.
  my ($ckey, $category, $headers, $popnum) = @_;
  my $n = scalar @$headers;
  logit("biffwatch($ckey, $category, [$n], $popnum)", 5) if $debug{biff} >= 4;
  if ($watchregex{$category}) {
    for my $sc (@{$watchregex{$category}}) {
      my ($subcat, $regex, $action, $fields, $callback) = @$sc;
      $action ||= 'notify';
      my @match = grep { $_ =~ $regex;
                       } @$headers;
      if (scalar @match) {
        my $detail = join " / ", map { $_ =~ $regex; $1; } @match;
        my $scname = ($subcat eq $category) ? $subcat : "$category / $subcat";
        logit("biffwatch: matched $scname ($detail)", 6) if $debug{biff} >= 4;
        if ($action eq 'notify') {
          biffnotify($ckey, $category, $detail, $headers, $popnum);
        } elsif ($action eq 'readsubject') {
          my @subj = grep { /^Subject[:]/ } @$headers;
          if ($irc{maxlines} < scalar @subj) {
            my $nmore = 0;
            while ($irc{maxlines} <= scalar @subj) { pop @subj; $nmore++; }
            push @subj, "($nmore additional Subject lines not shown.)";
          }
          say($_,  channel => 'private', sender => $irc{oper});
        } elsif ($action eq 'readbody') {
          say("New $scname message [$detail] ($ckey:$popnum):", channel => 'private', sender => $irc{oper} );
          biffnotify($ckey, $category, $detail, $headers, $popnum);
          my $box = findrecord('popbox', 'mnemonic', $ckey);
          my $srv = getrecord('popserver', $$box{server});
          my $pop = new Mail::POP3Client( USER      => $$box{popuser},
                                          PASSWORD  => $$box{poppass},
                                          HOST      => $$srv{serveraddress});
          if (ref $pop) {
            if ($pop->Connect() >= 0) {
              my $count = $pop->Count();
              logit("POP3 Count: $count ($ckey => $$conf{user} on $$conf{server})") if $debug{pop3} > 1;
              my @retr; # Just in case.
              my @head = $pop->Head($popnum);
              if (not @head) {
                say("POP3 Server is Apparently Retarded ($ckey)", channel => 'private', sender => $irc{oper});
                @retr = $pop->Retrieve($popnum);
                say("Retrieved " . @retr . " lines total", channel => 'private', sender => $irc{oper});
                my $l = shift @retr; chomp $l;
                while (not $l =~ /^$/) {
                  push @head, $l;
                  $l = shift @retr;
                }
              }
              my @subj = grep { /Subject[:]/ } @head;
              if ($irc{maxlines} > scalar @subj) {
                if (scalar @subj) {
                  for my $l (@subj) {
                    chomp $l;
                    say($l, channel => 'private', sender => $irc{oper} );
                    select undef, undef, undef, (0.1 * scalar @line);
                  }
                } else {
                  say("No Subject: header found (out of " . @head . " header lines total)",
                      channel => 'private', sender => $irc{oper});
                }
              } else {
                say("Too many subject lines (" . @subj . ")", channel => 'private', sender => $irc{oper} );
              }
              my @line = $pop->Body($popnum);
              if (not scalar @line) {
                # more retarded POP3 server stuff
                push @line, $_ for @retr;
              }
              if ($irc{maxlines} >= scalar @line) {
                if (@line) {
                  for my $l (@line) {
                    chomp $l;
                    say($l, channel => 'private', sender => $irc{oper} );
                    select undef, undef, undef, (0.1 * scalar @line);
                  }
                } else {
                  say("[The body of the message is empty.]", channel => 'private', sender => $irc{oper} );
                }
              } else {
                say("Message body is too long to read here.", channel => 'private', sender => $irc{oper} );
              }
            } else {
              say("POP3: failed to connect to server ($ckey)", channel => 'private', sender => $irc{oper} );
            }
          } else {
            say("Mail::POP3Client constructor failed ($ckey)", channel =>'private', sender => $irc{oper});
          }
        } # TODO: other actions can be implemented here, e.g. parsing a substring out of the body.
          else {
          logit("biffwatch: unknown action, $action; defaulting to notify");
          biffnotify($ckey, $category, $detail, $headers, $popnum);
        }
      } else {
        logit("biffwatch: no match for $category", 6) if $debug{biff} >= 4;
        if ($debug{biff} > 7) {
          logit($_, 7) for @$headers;
        }
      }
    }
  #} elsif ($category eq 'personal') { # TODO
  #  logit("biffwatch: do not know how to watch for personal mail.", 6);
  #} elsif ($category eq 'gpl') { # TODO
  #  logit("biffwatch: do not know how to watch for gpl mail.", 6);
  } else {
    logit("Unknown watch category: $category", 6);
    warn "Unknown watch category: $category";
  }
}

sub biffnotify {
  my ($ckey, $category, $detail, $headers, $popnum) = @_;
  my @from = grep { /^From:/i } @$headers;
  if (not @from) {
    @from = grep { /^(X-)?Sender:/i } @$headers;
    if (not @from) {
      @from = grep { /^Reply-to:/i } @$headers;
    }
  }
  my $pnum = $popnum ? ":$popnum" : '';
  my @faddr = map { /(\S+[@]\S+)/; $1; } grep { /\S+[@]\S+/ } @from;
  my $from = (scalar @faddr) ? ", from $faddr[0]" : '';
  push @notification, qq[$category message [$detail] received (for $ckey$pnum)$from];
}

sub processnotification {
  my $operator = $irc{oper};
  # TODO: First check that the operator is actually here.
  # For now, I'm going to just kind of assume that:
  my $message = shift @notification;
  logit("Processing Notification: $message");
  say($message,
      channel => 'private',
      sender  => $operator,
     );
  select undef, undef, undef, (0.2 * scalar @notification); # Don't trip flood protection.
}

sub setalarm {
  my ($dt, $text, %arg) = @_;
  my $alarm = +{ nick      => ($arg{nick} || $arg{sender}),
                 sender    => $arg{sender},
                 setdate   => DateTime::Format::ForDB(DateTime->now(@tz)),
                 alarmdate => DateTime::Format::ForDB($dt),
                 message   => ($text || "Alarm!"),
                 status    => 0, # 0 = active; 1 = inactive
               };
  $alarm{nick} = $alarm{sender} unless $irc{master}{$arg{sender}};
  my $result = addrecord("alarm", $alarm);
  my $id = $db::added_record_db;
  if ($result) {
    say("Alarm set for " . (friendlytime($dt), getircuserpref($arg{nick}, 'timezone') || $prefdefault{timezone} || $servertz)
        . " ($id)", %arg);
  } else {
    say("Failed to set alarm", %arg);
  }
}

42;
