#!/usr/bin/perl

package dbconfig;

our $database = 'jonadabot';
our $host     = 'localhost';
our $user     = 'jonadabot_db_username';
our $password = 'jonadabot_db_password';

%main::dbconfig =
  (
   database => $database,
   host     => $host,
   user     => $user,
   password => $password,
  );

