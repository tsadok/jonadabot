
#our $dbcode           = "jonadabot_db.pl";
#do  $dbcode;

my $db = dbconn();

###################################################################
# Basic tables used for fundamental functionality of the IRC bot: #
###################################################################

sub ctine { # PostgreSQL's verbose equivalent to CREATE TABLE IF NOT EXISTS
  my ($tablename, $fields) = @_;
  return qq[IF EXISTS ( SELECT *
   FROM  pg_catalog.pg_tables
   WHERE schemaname = '$dbconfig{dbname}'
   AND   tablename  = '$tablename'
  ) THEN RAISE NOTICE 'Table $tablename already exists';
  ELSE CREATE TABLE $tablename (
     $fields );
  END IF;\n];
}

# configuration variables:
my $q = $db->prepare(ctine('config',
    "id         SERIAL,
     cfgprofile VARCHAR(255),
     enabled    int2,
     varname    VARCHAR(64),
     value      VARCHAR(65535)"));
$q->execute();

# individual IRC users' preferences:
my $q = $db->prepare(ctine("userpref",
    "id           SERIAL,
     username     VARCHAR(255),
     prefname     VARCHAR(255),
     value        VARCHAR(512)"));
$q->execute();

# record of when the bot has started (used for restart-flood protection):
my $q = $db->prepare(ctine("startuprecord",
    "id           SERIAL,
     whenstarted  DATETIME,
     psid         int4,
     flags        VARCHAR(255)"));
$q->execute();

# messages for individual IRC users:
$q = $db->prepare(ctine("memorandum",
    "id         SERIAL,
     sender     VARCHAR(255),
     channel    VARCHAR(255),
     target     VARCHAR(255),
     thedate    datetime,
     message    VARCHAR(512),
     status     int2,
     statusdate datetime"));
$q->execute();

# when various IRC users were last seen:
$q = $db->prepare(ctine("seen",
    "id         SERIAL,
     nick       VARCHAR(255),
     channel    VARCHAR(255),
     whenseen   datetime,
     details    VARCHAR(512),
     notes      tinytext"));
$q->execute();

# alarms set by individual IRC users:
$q = $db->prepare(ctine("alarm",
    "id         SERIAL,
     status     int2,
     nick       VARCHAR(255),
     sender     VARCHAR(255),
     setdate    datetime,
     alarmdate  datetime,
     message    VARCHAR(512),
     viewed     datetime,
     snoozetill datetime,
     viewcount  int4,
     flags      VARCHAR(255)"));
$q->execute();

# recurring alarms set by individual IRC users:
$q = $db->prepare(ctine("recurringalarm",
    "id          SERIAL,
     nick        VARCHAR(255),
     sender      VARCHAR(255),
     setdate     datetime,
     dayofmonth  int2,
     dayofweek   int2,
     hour        int2,
     minute      int2,
     lasttripped datetime,
     message     VARCHAR(512),
     flags       VARCHAR(255)"));
$q->execute();

# Custom Triggers:

$q = $db->prepare(ctine("bottrigger",
    "id            SERIAL,
     bottrigger    VARCHAR(255),
     answer        VARCHAR(512),
     enabled       int2,
     flags         VARCHAR(255)"));
$q->execute();

# Backscroll:

$q = $db->prepare(ctine("backscroll",
    "id             SERIAL,
     channel        VARCHAR(255),
     number         int4,
     whensaid       datetime,
     speaker        VARCHAR(255),
     flags          VARCHAR(255),
     message        VARCHAR(512)"));
$q->execute();

###################################################################
# Tables related to email and SMS features:                       #
###################################################################

# POP3 servers:
$q = $db->prepare(ctine("popserver",
    "id            SERIAL,
     serveraddress VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# POP3 mailboxes:
$q = $db->prepare(ctine("popbox",
    "id         SERIAL,
     ownernick  VARCHAR(255),
     address    VARCHAR(255),
     popuser    VARCHAR(255),
     poppass    VARCHAR(512),
     server     int4,
     mnemonic   VARCHAR(255),
     count      int4,
     flags      VARCHAR(255)"));
$q->execute();

# Assignment of watch keys to POP3 mailboxes:
$q = $db->prepare(ctine("popwatch",
    "id         SERIAL,
     popbox     int4,
     watchkey   VARCHAR(255),
     flags      VARCHAR(255)"));
$q->execute();

# SMS (cellular short text message service) carriers:
$q = $db->prepare(ctine("smscarrier",
    "id           SERIAL,
     carriername  VARCHAR(255),
     flags        VARCHAR(255)"));
$q->execute();

# Email-to-SMS gateways:
$q = $db->prepare(ctine("smscarriergate",
    "id            SERIAL,
     carrier       int4,
     domain        VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# SMS Destinations, i.e., individual people's phones:
$q = $db->prepare(ctine("smsdestination",
    "id            SERIAL,
     carrier       int4,
     fullname      VARCHAR(255),
     phnumber      VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# Individual users' mnemonics/abbreviations for SMS destinations:
$q = $db->prepare(ctine("smsmnemonic"
    "id            SERIAL,
     destination   int4,
     ircnick       VARCHAR(255),
     mnemonic      VARCHAR(255),
     bcc           VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# SMTP servers for sending mail:
$q = $db->prepare(ctine("smtp",
    "id            SERIAL,
     server        VARCHAR(255),
     bcc           VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# Standard email destinations:
$q = $db->prepare(ctine("emaildest",
    "id            SERIAL,
     address       VARCHAR(255),
     bcc           VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# Individual users' email contacts:
$q = $db->prepare(ctine("emailcontact",
    "id            SERIAL,
     mnemonic      VARCHAR(255),
     ircnick       VARCHAR(255),
     emaildest     int4,
     signature     VARCHAR(255),
     flags         VARCHAR(255)"));
$q->execute();

# Outgoing Mail Queue:
$q = $db->prepare(ctine("mailqueue",
    "id            SERIAL,
     tofield       VARCHAR(255),
     fromfield     VARCHAR(255),
     nick          VARCHAR(255),
     subject       VARCHAR(512),
     bcc           VARCHAR(255),
     enqueued      datetime,
     trycount      int4,
     dequeued      datetime,
     body          VARCHAR(65535)"));
$q->execute();

# Notifications about incoming mail that biff has noticed:
$q = $db->prepare(ctine("notification",
    "id            SERIAL,
     usernick      VARCHAR(255),
     enqueued      datetime,
     dequeued      datetime,
     flags         VARCHAR(255),
     message       VARCHAR(512)"));
$q->execute();

###################################################################
# Tables related to logfile watching:                             #
###################################################################

# log files to watch:
$q = $db->prepare(ctine("logfile",
    "id         SERIAL,
     mnemonic   VARCHAR(255),
     logfile    VARCHAR(512),
     flags      VARCHAR(255)"));
$q->execute();

# key things to watch for in those log files:
$q = $db->prepare(ctine("logfilewatch"
    "id           SERIAL,
     logfile      int4,
     matchstring  VARCHAR(255),
     isregexkey   int2,
     nicktomsg    VARCHAR(255),
     msgprefix    VARCHAR(255),
     channel      VARCHAR(255),
     chanprefix   VARCHAR(255),
     flags        VARCHAR(255)"));
$q->execute();

# logfile lines that have already been announced
$q = $db->prepare(ctine("announcement",
    "id         SERIAL,
     context    VARCHAR(255),
     whenseen   datetime,
     expires    datetime,
     detail     VARCHAR(512),
     note       VARCHAR(512)"));
$q->execute();

###################################################################
# Tables related to junethack game tournament clan support:       #
###################################################################

$q = $db->prepare(ctine("clanmemberid",
    "id             SERIAL,
     year           int4,
     clanname       VARCHAR(255),
     tourneyaccount VARCHAR(255),
     flags          VARCHAR(255)"));
$q->execute();

$q = $db->prepare(ctine("clanmembernick",
    "id         SERIAL,
     memberid   int4,
     nick       VARCHAR(255),
     prio       int4"));
$q->execute();

$q = $db->prepare(ctine("clanmembersrvacct",
    "id            SERIAL,
     memberid      int4,
     serveraccount VARCHAR(255),
     servertla     VARCHAR(255)"));
$q->execute();

