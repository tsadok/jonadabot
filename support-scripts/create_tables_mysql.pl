
#our $dbcode           = "jonadabot_db.pl";
#do  $dbcode;

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
     details    tinytext,
     notes      tinytext)");
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

# Custom Triggers:

$q = $db->prepare("CREATE TABLE IF NOT EXISTS bottrigger (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     bottrigger    tinytext,
     answer        tinytext,
     enabled       integer,
     flags         tinytext)");
$q->execute();

# Backscroll:

$q = $db->prepare("CREATE TABLE IF NOT EXISTS backscroll (
     id             integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     channel        tinytext,
     number         integer,
     whensaid       datetime,
     speaker        tinytext,
     flags          tinytext,
     message        text)");
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
     bcc           tinytext,
     flags         tinytext)");
$q->execute();

# SMTP servers for sending mail:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS smtp (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     server        tinytext,
     bcc           tinytext,
     flags         tinytext)");
$q->execute();

# Standard email destinations:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS emaildest (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     address       tinytext,
     bcc           tinytext,
     flags         tinytext)");
$q->execute();

# Individual users' email contacts:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS emailcontact (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     mnemonic      tinytext,
     ircnick       tinytext,
     emaildest     integer,
     signature     tinytext,
     flags         tinytext)");
$q->execute();

# Outgoing Mail Queue:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS mailqueue (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     tofield       tinytext,
     fromfield     tinytext,
     nick          tinytext,
     subject       tinytext,
     bcc           tinytext,
     enqueued      datetime,
     trycount      integer,
     dequeued      datetime,
     body          text)");
$q->execute();

# Notifications about incoming mail that biff has noticed:
$q = $db->prepare("CREATE TABLE IF NOT EXISTS notification (
     id            integer NOT NULL AUTO_INCREMENT PRIMARY KEY,
     usernick      tinytext,
     enqueued      datetime,
     dequeued      datetime,
     flags         tinytext,
     message       tinytext)");
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



# TODO: offer to scrape clan member names off the junethack website, ask for the IRC nicks, and populate those tables too.
