#!/usr/bin/perl

use strict;

print "
*****************************************************
***  D A T A B A S E    C O N F I G U R A T I O N :
*****************************************************
";

my $whichdb = undef;
if (-e "jonadabot_dbconfig.pl") {
  do "jonadabot_dbconfig.pl";
  if ($main::dbconfig{rdbms} eq 'sqlite') {
    print "\nFound db config for SQLite:
    database file => $main::dbconfig{database}\n";
    $whichdb = 'S' if yesno("Continue to use SQLite?");
  } elsif ($main::dbconfig{rdbms} eq 'mysql') {
    my $hostname = ($main::dbconfig{host} eq 'localhost') ? 'localhost' : `hostname`;
    print "\nFound db config for MySQL.\n";
    $whichdb = 'M' if yesno("Continue to use MySQL?");
  }
}

print "
The bot uses a relational database to store information that needs to persist,
so that it doesn't lose its entire memory every time it gets disconnected or
needs to restart.  Possibilities include:
 M - MySQL    - this is the most thoroughly tested configuration currently
 S - SQLite   - store the database in a local file; does not require the
                system to be running a database service at the system level
     Postgres - currently not supported, but it would not be very difficult
                to backport support from the 007 branch (which never became
                stable for unrelated reasons but had working Pg support).
" unless $whichdb;

my $changedconfig = 0;
while (not ($whichdb =~ /^[MS]/i)) {
  $whichdb = askuser("Which relational database do you want the bot to use (M, S)?");
  $changedconfig = 1;
}
if ($whichdb =~ /^S/i) {
  $main::dbconfig{rdbms} = 'sqlite';
  print "DB Configuration for SQLite.\n";
  my $dbfile = $main::dbconfig{database};
  if ($dbfile and -e $dbfile) {
    print "Database file already exists: $dbfile\n";
    print "SQLite configuration is complete.\n";
  } elsif ($dbfile) {
    # Let's try to verify whether we can create a file there...
    print "DB filename configured: $dbfile\n";
    print "Checking whether that will work.\n";
    open TMP, ">", $dbfile; print TMP "1"; close TMP;
    if (-e $dbfile) {
      unlink $dbfile;
      print "  Yep, that should work.\n";
    } else {
      print "  WARNING: unable to create a file at $dbfile\n$!\n";
    }
    if (yesno("Do you want to change it (specify a new location for the DB file)? (y/n)")) {
      $dbfile = askuser("New path and filename for database file (default: $dbfile):") || $dbfile;
      $changedconfig++ unless $dbfile eq $main::dbconfig{database};
      $main::dbconfig{database} = $dbfile;
    }
  } else {
    $dbfile = askuser("Path and filename where you want to store the database file (default: jonadabot.sqlite):")
      || "jonadabot.sqlite";
    $changedconfig++;
  }
  $main::dbconfig{database} = $dbfile;
} else {
  $main::dbconfig{rdbms} = 'mysql';
  print "DB Configuration for MySQL.\n";

  my $dbname = $main::dbconfig{database};
  my $default = $dbname || 'jonadabot';
  $main::dbconfig{database} = askuser("What do you want to call the database? (default: $default)") || $default;
  $changedconfig++ unless $dbname eq $main::dbconfig{database};

  my $host = $main::dbconfig{host};
  my $defaulthost = $host || 'localhost';
  $main::dbconfig{host} = askuser("What host is the database service running on?  (default: $defaulthost)") || $defaulthost;
  $changedconfig++ unless $host eq $main::dbconfig{host};

  my $user = $main::dbconfig{user};
  my $defaultuser = $user || 'jonadabot';
  $main::dbconfig{user} = askuser("What MySQL user should the bot use to conect to the database?  (default: $defaultuser)") || $defaultuser;
  $changedconfig++ unless $user eq $main::dbconfig{user};

  my $pass = $main::dbconfig{password};
  my $defaultpass = $pass || newpassword();
  $main::dbconfig{password} = askuser("What password should $main::dbconfig{user} use to connect to the database?  (default: $defaultpass)") || $defaultpass;
  $changedconfig++ unless $pass eq $main::dbconfig{password};

  if ($main::dbconfig{database} and $main::dbconfig{host} and
      $main::dbconfig{user} and $main::dbconfig{password}) {
    print "\n----------------------Note:----------------------\n
    If you have not done so already, please issue the following SQL commands
    at the MySQL prompt:
       CREATE DATABASE $main::dbconfig{database};
       GRANT ALL PRIVILEGES ON $main::dbconfig{database}.*
          TO $user" . '@' . "$main::dbconfig{hostname} IDENTIFIED BY $main::dbconfig{password};
       FLUSH PRIVILEGES;\n----------------------Note:----------------------\n\n";
    } else {
      print "\nWARNING:  Your DB configuration seems incomplete.\n";
    }
}

if ($changedconfig and
    yesno("You changed $changedconfig database configuration options.  Save these changes?")) {
  open CFG, ">", "jonadabot_dbconfig.pl"
    or die "Unable to write jonadabot_dbconfig.pl: $!";
  my $scalar = '$';
  my $hash   = '%';
  my @field  = qw(rdbms database host user password);
  print CFG qq[#!/usr/bin/perl\n\npackage dbconfig;\n\n]
    . (join "\n", grep { $_ } map {
#      $main::dbconfig{$_} ?
        qq[our ${scalar}$_    = '$main::dbconfig{$_}';]
#        : undef
      } @field)
    . qq[\n\n${hash}main::dbconfig =\n  (\n]
    . (join "\n", grep { $_ } map {
      $main::dbconfig{$_}
        ? qq[   $_    => ${scalar}$_,]
        : undef
      } @field) . "\n   );\n42;\n";
  close CFG;
  print "Next steps:
 * run the createtables script (if you haven't already):
   perl jonadabot_createtables_$main::dbconfig{rdbms}.pl
 * create timezone.pl (see timezone_sample.pl for an example)\n";
}

exit 0; # Subroutines follow.

sub newpassword {
  my @c = ('a' .. 'h', 'j', 'k', 'm' .. 'z', 'A' .. 'H', 'J' .. 'N', 'P' .. 'Z', '2' .. '9');
  return join "", map { $c[rand @c] } 1 .. 50;
}

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

