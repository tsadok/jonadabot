#!/usr/bin/perl

package dbconfig;

our $rdbms    = 'sqlite';
our $database = '/home/jonadabot/jonadabot.sqlite';
# NOTE: although the actual database all goes in the $database file,
# the directory containing it must be writable by jonadabot, because
# the DBD::SQLite driver will create temporary files there at times.

# However, we don't need a host or user or password for sqlite.  We
# can read and write the database provided the filesystem permissions
# on the database file allow us to read and write the database file.

%main::dbconfig =
  (
   rdbms    => $rdbms,
   database => $database,
   host     => $host,
   user     => $user,
   password => $password,
  );

