#!/usr/bin/perl
# -*- cperl -*-

# Database functions:
# ADD:     $result  = addrecord(tablename, $record_as_hashref);
# UPDATE:  @changes = @{updaterecord(tablename, $record_as_hashref)};
# GET:     %record  = %{getrecord(tablename, id)};
# NEXT:    $record =  getnext(tablename, field, oldvalue); # Returns a record with a value just greater than oldvalue in field.
# NEXT:    $record =  getnext(tablename, field1, oldvalue, field2, value2) # Like above, but exclude records where field2 doesn't match this value; additional field/value pairs may be specified if desired.
# GETALL:  @records = getrecord(tablename);     # Not for enormous tables.
# GETNEW:  @records = getsince(tablename, datetimefield, datetimeobject);
# OVERLAP: @records = finddateoverlap(tablename, startfield, endfield, startdt, enddt);
# FIND:    @records = findrecord(tablename, fieldname, exact_value [, fieldname, value, ...]);
# FINDNUL: @records = findnull(tablename, nullfield); # can also specify field/value pairs to match
# FINDNEW: @records = findsince(tablename, datetimefield, datetimeobject, fieldname, exact_value [, fieldname, exact_value, ...]);
# SEARCH:  @records = searchrecord(tablename, fieldname, value_substring);
# COUNT:   %counts  = %{countfield(tablename, fieldname)}; # Returns a hash with counts for each value.
# COUNT:   %counts  = %{countfield(tablename, fieldname, start_dt, end_dt)}; # Ditto, but within the date range; pass DateTime objects.
# GET BY DATE:        (Last 3 args optional.  Dates, if specified, must be formatted for MySQL already.)
#          @records = @{getrecordbydate(tablename, datefield, mindate, maxdate, maxfields)};
# DELETE:  $result  = deleterecord('tablename', $id);

use strict;
use DBI();
use Carp;
our $servertz;

require "jonadabot_dbconfig.pl";

if ($dbconfig{rdbms} eq 'mysql') {
  do "jonadabot_db_mysql.pl";
} elsif ($dbconfig{rdbms} eq 'postgres') {
  do "jonadabot_db_postgres.pl";
} # TODO: support additional RDBMS options here.  Notably, I want to do SQLite support.
else {
  die "Unsupported/unknown/misspelled RDBMS: '$dbconfig{rdbms}'";
}

# Some database functions are not specific to any particular RDBMS
# (because they call lower-level DB functions to do any RDBMS-specific
# parts).  Such functions follow below.  However, anything with any
# actual SQL in it should bo in the RDBMS-specific code.

sub getconfigvarordie {
  my ($p, $v) = @_;
  if (wantarray) {
    my @answer = getconfigvar(@_);
    croak "You MUST configure at least one value for config variable $v in profile $p" if not @answer;
    return @answer;
  } else {
    my $answer = getconfigvar(@_);
    croak "You MUST configure a value for config variable $v in profile $p" if not $answer;
    return $answer;
  }
}
sub getconfigvar {
  my ($profile, $varname) = @_;
  my @cfgvar = findrecord('config', 'cfgprofile', $profile, 'varname', $varname, 'enabled', 1);
  if (wantarray) {
    return map { $$_{value} } @cfgvar;
  } elsif (1 >= scalar @cfgvar) {
    return $cfgvar[0]{value};
  } else {
    warn "Too many enabled config values for $varname in profile $profile, only the first will be used.";
    return $cfgvar[0]{value};
  }
}

sub getvariable {
  my ($name, $userid) = @_;
  my $r = ($userid and findrecord('userpref', 'name', $name, 'user', $userid)) || findrecord('variable', 'name', $name);
  if (ref $r) {
    if (defined $$r{string}) { return $$r{string}; } # So, yeah, the empty string is a possible value.
    return $$r{number} || undef;
  } else {
    #carp "Failed to find variable: $name";
    return;
  }
}

sub setuserpref {
  my ($name, $value, $userid) = @_;
  my $r = findrecord('userpref', 'name', $name, 'user', $userid);
  if (ref $r) {
    if ($value =~ /^\d+$/) { $$r{number} = $value; $$r{string} = undef; }
    else { $$r{string} = $value; }
    updaterecord('userpref', $r);
  } else {
    my $r = +{ user => $userid, name => $name };
    if ($value =~ /^\d+$/) { $$r{number} = $value; }
    else { $$r{string} = $value; }
    addrecord('userpref', $r);
  }
}

sub clearuserpref {
  my ($name, $userid) = @_;
  my $r = findrecord('userpref', 'name', $name, 'user', $userid);
  if (ref $r) {
    deleterecord('userpref', $r);
  }
}

sub setvariable {
  my ($name, $value, $userid) = @_;
  if ($userid) {
    setuserpref($name, $value, $userid);
  } else {
    my $r = findrecord('variable', 'name', $name);
    if (ref $r) {
      if ($value =~ /^\d+$/) { $$r{number} = $value; }
      else { $$r{string} = $value; }
      updaterecord('variable', $r);
    } else {
      my $r = +{ name => $name };
      if ($value =~ /^\d+$/) { $$r{number} = $value; }
      else { $$r{string} = $value; }
      addrecord('variable', $r);
    }}
}


42;
