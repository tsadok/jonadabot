
our $devname          = 'jonadabot';
our $version          = '006';
our $dbcode           = "jonadabot_db.pl";
our $utilsubs         = "jonadabot_utilsubs.pl";
our $defaultnick      = "jonadabot_" . 65535 + int rand 19450726;
do  $dbcode;
do  $utilsubs;
our $cfgprofile       = askuser("Enter a short identifier for your configuration profile (default: jonadabot)") || 'jonadabot';


my $db = dbconn();

###################################################################
# Basic tables used for fundamental functionality of the IRC bot: #
###################################################################

# configuration variables:
my $q = $db->prepare("CREATE TABLE IF NOT EXISTS config (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     cfgprofile tinytext,
     enabled    integer,
     varname    tinytext,
     value      text)");
$q->execute();

# individual IRC users' preferences:
my $q = $db->prepare("CREATE TABLE IF NOT EXISTS userpref (
     id           integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     username     tinytext,
     prefname     tinytext,
     value        text)");
$q->execute();

# record of when the bot has started (used for restart-flood protection):
my $q = $db->prepare("CREATE TABLE IF NOT EXISTS startuprecord (
     id           integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     whenstarted  datetime,
     psid         tinytext,
     flags        tinytext)");
$q->execute();

# messages for individual IRC users:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS memorandum (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     sender     tinytext,
     channel    tinytext,
     target     tinytext,
     thedate    datetime,
     message    text,
     status     integer,
     statusdate datetime)");
$q->execute();

# when various IRC users were last seen:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS seen (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     nick       tinytext,
     channel    tinytext,
     whenseen   datetime,
     details    tinytext)");
$q->execute();

# alarms set by individual IRC users:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS alarm (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     status     integer,
     nick       tinytext,
     sender     tinytext,
     setdate    datetime,
     alarmdate  datetime,
     message    tinytext,
     viewed     datetime,
     snoozetill datetime,
     viewcount  integer,
     flags      tinytext)");
$q->execute();

# recurring alarms set by individual IRC users:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS recurringalarm(
     id          integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     nick        tinytext,
     sender      tinytext,
     setdate     datetime,
     dayofmonth  integer,
     dayofweek   integer,
     hour        integer,
     minute      integer,
     lasttripped datetime,
     message     text,
     flags       tinytext)");
$q->execute();

###################################################################
# Tables related to email and SMS features:                       #
###################################################################

# POP3 servers:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS popserver (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     serveraddress tinytext,
     flags         tinytext)");
$q->execute();

# POP3 mailboxes:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS popbox (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     ownernick  tinytext,
     address    tinytext,
     popuser    tinytext,
     poppass    tinytext,
     server     integer,
     mnemonic   tinytext,
     count      integer,
     flags      tinytext)");
$q->execute();

# Assignment of watch keys to POP3 mailboxes:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS popwatch (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     popbox     integer,
     watchkey   tinytext,
     flags      tinytext)");
$q->execute();

# SMS (cellular short text message service) carriers:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smscarrier (
     id           integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     carriername  tinytext,
     flags        tinytext)");
$q->execute();

# Email-to-SMS gateways:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smscarriergate (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     carrier       integer,
     domain        tinytext,
     flags         tinytext)");
$q->execute();

# SMS Destinations, i.e., individual people's phones:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smsdestination (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     carrier       integer,
     fullname      tinytext,
     phnumber      tinytext,
     flags         tinytext)");
$q->execute();

# Individual users' mnemonics/abbreviations for SMS destinations:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smsmnemonic (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     destination   integer,
     ircnick       tinytext,
     mnemonic      tinytext,
     flags         tinytext)");
$q->execute();

# SMTP servers for sending mail:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smtp (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     server        tinytext,
     bcc           tinytext,
     flags         tinytext)");
$q->execute();

###################################################################
# Tables related to logfile watching:                             #
###################################################################

# log files to watch:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS logfile (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     mnemonic   tinytext,
     logfile    tinytext,
     flags      tinytext)");
$q->execute();

# key things to watch for in those log files:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS logfilewatch (
     id           integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     logfile      integer,
     matchstring  tinytext,
     isregexkey   integer,
     nicktomsg    tinytext,
     msgprefix    tinytext,
     channel      tinytext,
     chanprefix   tinytext,
     flags        tinytext)");
$q->execute();

# logfile lines that have already been announced
$q = $db->prepare("CREATE TABLE IF NOT EXISTS announcement (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     context    tinytext,
     whenseen   datetime,
     expires    datetime,
     detail     text,
     note       tinytext)");
$q->execute();

###################################################################
# Tables related to junethack game tournament clan support:       #
###################################################################

$q = $db->prepare("CREATE TABLE IF NOT EXISTS clanmemberid (
     id             integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     year           integer,
     clanname       tinytext,
     tourneyaccount tinytext,
     flags          tinytext)");
$q->execute();

$q = $db->prepare("CREATE TABLE IF NOT EXISTS clanmembernick (
     id         integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     memberid   integer,
     nick       tinytext,
     prio       integer)");
$q->execute();

$q = $db->prepare("CREATE TABLE IF NOT EXISTS clanmembersrvacct (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     memberid      integer,
     serveraccount tinytext,
     servertla     tinytext)");
$q->execute();

###################################################################
###################################################################
####  S E T U P :                                              ####
###################################################################
###################################################################

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

### Basic Configuration Setup:

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

### Email Setup:
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

### Logfile Watching Setup:

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
print("You will need to edit jonadabot_regexes.pl to add regular expressions for the following watch keys:
  " . commalist(sort { $a cmp $b } uniq(@regexkey)) . "\n") if @regexkey;

# TODO: offer to scrape clan member names off the junethack website, ask for the IRC nicks, and populate those tables too.
