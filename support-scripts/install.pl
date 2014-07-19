#!/usr/bin/perl
# -*- cperl -*-

use File::Spec::Functions;

our $devname          = 'jonadabot';
our $version          = '006';
our $dbcode           = "jonadabot_db.pl";
our $utilsubs         = "jonadabot_utilsubs.pl";
our $defaultnick      = "jonadabot_" . 65535 + int rand 19450726;
do  $utilsubs;

die "This script should be run from the main jonadabot directory (where jonadabot.pl is located)"
  if not -e "jonadabot.pl";

################# Step 1: DB Config

if (not -e "jonadabot_dbconfig.pl") {
  print "jonadabot_dbconfig.pl not found.  This is required.

You can copy the sample and edit it to suit.

Alternately, I can ask you some questions and try to
construct the DB config file for you.\n";

  if (yesno("Do you want me to try to build your DB config file?")) {
    print "Currently, there are two supported relational database systems.\n";
    print "MySQL support has been more thoroughly tested, but Postgres support\n";
    print "is now available as well.\n";
    my $rdbms = lc askuser("Which RDBMS do you want to use?");
    my %supportedrdbms = map { $_ => 1 } qw(mysql postgres);
    if ($supportedrdbms) {
      my $dbname = askuser("What do you want to call the database?  (default: jonadabot)")
        || 'jonadabot';
      my $dbhost = askuser("What host does the RDBMS run on?  (default: localhost)")
        || 'localhost';
      my $dbuser = askuser("Enter a username for the DB login  (default: jonadabot)")
        || 'jonadabot';
      print "Note that by necessity the login credentials will be stored in cleartext\n";
      print "in your DB config file, so choose a password you don't use for anything else.\n";
      my @char = ("A" .. "H", "J" .. "N", "P" .. "Z",
                  "a" .. "k", "m" .. "z", 2 .. 9, "_", ".", "-");
      my $dfltpass = join "", map { $char[rand @char] } 1 .. 35;
      my $dbpass = askuser("Enter a password for the DB login (default: $dfltpass)")
        || dfltpass;
      open DBCFG, ">", "jonadabot_dbconfig.pl";
      print DBCFG qq[#!/usr/bin/perl\n\npackage dbconfig;\n
our $rdbms    = '$rdbms';
our $database = '$dbname';
our $host     = '$dbhost';
our $user     = '$dbuser';
our $password = '$dbpass';\n
%main::dbconfig =\n  (
   rdbms    => $rdbms,
   database => $database,
   host     => $host,
   user     => $user,
   password => $password,
  );\n];
      close DBCFG;
      print "If you haven't done so already, you will need to create the $dbname database\n";
      print "and grant privileges on it to $dbuser and set $dbuser's password to $dbpass\n";
      print "before going any further.\n";
      if (not yesno("Have you already created the database and granted the privileges?")) {
        print "Run the install again when you have done so.";
        exit 0;
      }
    } else {
      print "At this time, only " . (join " and ", keys %supportedrdbms) . " are supported.\n";
      print "SQLite may be supported in the future, but that has not yet been implemented.\n";
      print "Run the install again after you have decided on a database system.\n";
      exit 1;
    }
  } else {
    print "Run the install again after you have created the DB config.\n";
    exit 1;
  }
}

do $dbcode;

################# Step 2: Create Tables:

my $create;
if ($dbconfig{rdbms} eq 'mysql') {
  $create = "support-scripts/create-tables_mysql.pl";
} elsif ($dbconfig{rdbms} eq 'postgres') {
  $create = "support-scripts/create-tables_postgres.pl";
} elsif ($dbconfig{rdbms} eq 'sqlite') {
  $create = "support-scripts/create-tables_sqlite.pl";
} else {
  die "Don't know how to create tables for RDBMS: '$dbconfig{rdbms}'";
}

if (-e $create) {
  do "$create";
} else {
  die "Could not find $create";
}

################# Step 3: Basic Config:

our $cfgprofile       = askuser("Enter a short identifier for your configuration profile (default: jonadabot)") || 'jonadabot';

my @var = (
           ['ircserver'            => 'irc.freenode.net', "Enter the domain name for an IRC network"],
           ['ircserverport'        => 6667, "Port on which to connect to the IRC server"],
           ["ircusername"          => $defaultnick, "Username to use when connecting to the IRC network"],
           ['ircrealname'          => 'anonymous ircbot operator', "Basic value for real name ('represented by $devname' will be added) when people /whois the bot"],
           ['ircpassword'          => '', "Password for the bot's IRC account login"],
           ['ircnickserv'          => 'NickServ', "Nick to /msg to log into the bot's IRC account"],
           ['ircemailaddress'      => '', "Email address associated with the bot's IRC account" ],
           ['ircnick'              => $defaultnick, "Nick to use once connected to the IRC network"],
           ['operatoremailaddress' => '', "Email address where the bot's primary operator can be reached"],
           ['defaultoperator'      => '', "Nick on the IRC network for the bot's primary human operator"],
           ['master'               => [], "Nick of a person who can send the bot privileged commands"],
           ['maxlines'             => 10, "Maximum number of lines to return at once when answering a trigger"],
           ['pingbot'              => ['Arsinoe', 'kotsovidalv'], "Other bot that will respond to /msg !ping to reset our timer"],
           ['pingtimelimit'        => [15, 30, 45, 60], "Number of seconds of no channel activity before pinging"],
           ['sibling'              => [], "Other instance of $devname run by the same operator; they help keep tabs on one another"],
           ['ircchannel'           => [], "IRC channel to always connect to on startup"],
           ['ircchanokdom'         => [], "IRC channel it is alright to dominate (be VERY sure you have permission from the ops)"],
           ['clan'                 => '', "Name of junethack tournament clan the IRC bot is assisting, if any"],
           ['wordfile'             => ["/usr/share/dict/words"], "Text file, one word or phrase per line, that can be used for games like hangman"],
           ['pubdirpath'           => '/var/www/jonadabot', "Filesystem path to a directory where the bot can publish files."],
           ['pubdiruri'            => 'http://www.example.com/jonadabot', "Public URL pointing to the same directory as pubdirpath"],
          );
my $questionsasked = 0;
for my $var (@var) {
  my ($varname, $default, $question) = @$var;
  if (not getconfigvar($cfgprofile, $varname)) {
    print "I may ask you some basic config questions.  Try to answer as best you can;\nbut don't worry: you can easily change your answers later in the config table in the database.\n\n"
      if not $questionsasked++;
    if (ref $default) {
      my @dflt = @$default;
      my $done = undef;
      while (not $done) {
        my $dflt     = shift @dflt;
        my $dfltnote = $dflt ? qq[ (default: $dflt)] : '';
        my $answer   = askuser("$question$dfltnote") || $dflt;
        if ($answer) {
          addrecord('config', +{ cfgprofile => $cfgprofile, varname => $varname, enabled => 1, value => ($answer || $dflt) });
        } else {
          $done++;
        }
      }
    } else {
      my $dfltnote = $default ? qq[ (default: $default)] : '';
      addrecord('config', +{ cfgprofile => $cfgprofile, varname => $varname, enabled => 1, value   => (askuser("$question$dfltnote") || $default) });
    }
  }
}

################# Step 4: Copy Files:

for my $customcode (qw(timezone jonadabot_regexes jonadabot_extrasubs)) {
  my $customfile = $customcode . ".pl";
  my $samplefile = $customcode . "_sample.pl";
  if (not -e $customfile) {
    print "Custom code file not found: $customfile\n";
    if (-e $samplefile) {
      if (yesno("Copy sample file ($samplefile) to $customfile?")) {
        system("cp", $samplefile, $customfile);
      } else {
        print "You will need to create $customfile\n";
      }
    } else {
      print "You will need to create $customfile\n";
    }
  }
}

# There are also the sample help files.
my $helporig = catfile("data-files", "bot-help.html");
if (-e $helporig) {
  for my $pubdir (getconfigvar($cfgprofile, "pubdirpath")) {
    my $dest = catfile($pubdir, "bot-help.html");
    if (yesno("Copy sample bot-help.html to $dest?")) {
      system("cp", $helporig, $dest);
      my $cssorig = catfile("data-files", "arsinoe.css");
      if (-e $cssorig) {
        my $cssdest = catfile($$pubdir{value}, "arsinoe.css");
        if (yesno("Also copy sample stylesheet to $cssdest?")) {
          system("cp", $cssorig, $cssdest);
        } else {
          warn "Not found: $cssorig";
        }
      }
    }
  }
} else {
  warn "Not found: $helporig\n";
}

################# Step 5: Email Setup:

my @regexkey;

if ((not getrecord("popserver")) and (yesno("Do you wish to set up email-related features?"))) {
  my $doanother = 1; while ($doanother) {
    my $serveraddress = askuser("Fully qualified domain name of a POP3 server");
    addrecord("popserver", +{ serveraddress => $serveraddress });
    my $serverid = $db::added_record_id;
    my $anotherbox   = 1; while ($anotherbox) {
      my $popuser    = askuser("POP3 username on $serveraddress"); if ($popuser) {
        my $poppass  = askuser("POP3 password for $popuser on $serveraddress");
        my $address  = askuser("Email address corresponding to $popuser on $serveraddress");
        my $owner    = askuser("IRC nick of user who owns this email account");
        my $mnemonic = askuser("Short mnemonic $owner can use to refer to this email account");
        addrecord("popbox", +{ ownernick  => $owner,
                               address    => $address,
                               popuser    => $popuser,
                               poppass    => $poppass,
                               server     => $serverid,
                               mnemonic   => $mnemonic });
        my $popid = $db::added_record_id;
        print qq[A "watch key" is just a short identifier that your jonadabot_regexes.pl\ncan key in when selecting a set of regular expressions to apply.\n];
        for my $watch (grep { $_ } split /\s+/,
                       askuser("Space-separated list of watch keys to apply to this email account")) {
          addrecord("popwatch", +{ popbox => $popid, watchkey => $watch });
          push @regexkey, $watch;
        }
        $anotherbox  = yesno("Add another mailbox/account on $serveraddress?");
      } else {
        $anotherbox = undef;
      }
    }
    $doanother = yesno("Add another POP3 server?");
  }

  if (yesno("Set up the ability to send email (via SMTP)?")) {
    my $server = askuser("Fully qualified domain name of your ISP's (or your own) SMTP gateway");
    my $bcc    = askuser(qq[Email address that should always get a "blind" copy (Bcc) of everything sent]);
    addrecord("smtp", +{ server => $server, bcc => $bcc, });
    # Wow, that was easy.  Let's do _one_ little extra thing that adds lots of complication:
    my $anothersms = "an";
    while (yesno("Set up $anothersms SMS (cellphone text message) carrier?")) {
      my $cname  = askuser("Name of carrier");
      my $domain = askuser("Domain of ${cname}'s main email-to-SMS gateway");
      addrecord("smscarrier", +{ carriername => $cname });
      my $cid    = $db::added_record_id;
      addrecord("smscarriergate", +{ carrier => $cid, domain => $domain });
      my $anotherdest = "a";
      while (yesno("Set up $anotherdest destination phone number on ${cname}'s network?")) {
        my $phnumber = askuser("Phone number (digits only)");
        my $fullname = askuser("Full name of person reached at this number");
        addrecord("smsdestination", +{ carrier   => $cid,
                                       phnumber  => $phnumber,
                                       fullname  => $fullname,
                                     });
        my $destid = $db::added_record_id;
        my $anothermnemonic = "a";
        while (yesno("Set up $anothermnemonic mnemonic for an IRC user to use to refer to this SMS target?")) {
          my $ircnick  = askuser("IRC nick of user who can use this mnemonic to send to this SMS target");
          my $mnemonic = askuser("Short identifier $ircnick can use to refer to this SMS target");
          addrecord("smsmnemonic", +{ destination => $destid,
                                      ircnick     => $ircnick,
                                      mnemonic    => $mnemonic, });
          $anothermnemonic = "another";
        }
        $anotherdest = "another";
      }
      $anothersms   = "another";
    }
  }
}


################# Step 6: Logfile Watching:

if (not getrecord("logfile")) {
  my $anotherlogfile = "a";
  while (yesno("Set up $anotherlogfile log file to watch?")) {
    my $logfile  = askuser("Path and file name of a log file to watch");
    my $mnemonic = askuser("Short mnemonic name for this log file");
    addrecord("logfile", +{ logfile => $logfile, mnemonic => $mnemonic });
    my $lfid = $db::added_record_id;
    my $anotherwatch = 1; while ($anotherwatch) {
      my $matchstring = askuser("Simple substring to watch for, or key that will identify one or more regular expressions");
      my $isregexkey  = yesno("Is this a key that will identify one or more regular expressions?");
      my $nicktomsg   = askuser("IRC nick of user to /msg when a match is found (leave blank for none)");
      my $msgprefix   = $nicktomsg ? (askuser("Prefix to prepend to a matching line when doing /msg $nicktomsg") || $mnemonic) : undef;
      my $channel     = askuser("IRC channel to send matching lines to (be CERTAIN you have permission from ops)");
      my $chanprefix  = $channel ? (askuser("Prefix to prepend when sending matching lines to $channel") || $mnemonic) : undef;
      push @regexkey, $matchstring if $isregexkey;
      addrecord("logfilewatch", +{ logfile     => $lfid,
                                   matchstring => $matchstring,
                                   isregexkey  => (($isregexkey) ? 1 : 0),
                                   nicktomsg   => $nicktomsg,
                                   msgprefix   => $msgprefix,
                                   channel     => $channel,
                                   chanprefix  => $chanprefix, });
      $anotherwatch = yesno("Add another thing to watch for in this log?");
    }
    $anotherlogfile = "another";
  }
}

################# Step 7: Regex Setup:
# For now, punt this to the user:
print("You will need to edit jonadabot_regexes.pl to add regular expressions for the following watch keys:
  " . commalist(sort { $a cmp $b } uniq(@regexkey)) . "\n") if @regexkey;


################# Step 8: Testing
# TODO

exit 0;
################# Subroutines:

sub askuser {
  my ($question) = @_;
  $| = 1;
  print $question . " \t";
  my $answer = <STDIN>;
  chomp $answer;
  return $answer;
}

sub yesno {
  my ($question) = @_;
  my $answer = askuser($question);
  return if $answer =~ /no/;
  return "yes" if $answer =~ /yes/;
  return if $answer =~ /n/;
  return "yes" if $answer =~ /y/;
  print "Please answer yes or no.\n";
  return yesno($question);
}

