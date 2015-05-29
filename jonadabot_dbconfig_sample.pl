#!/usr/bin/perl

package dbconfig;

our $rdbms    = 'mysql';
our $database = 'jonadabot';
our $host     = 'localhost';
our $user     = 'jonadabot_db_username';
our $password = 'jonadabot_db_password';

%main::dbconfig =
  (
   rdbms    => $rdbms,
   database => $database,
   host     => $host,
   user     => $user,
   password => $password,
  );

