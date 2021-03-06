#!/usr/bin/perl
# -*- cperl -*-

# This is the SQLite implementation of jonadabot_db.pl

# It is suggested to install DBI::Shell for the dbish utility
# so that you can access the db from the command line like so:
# dbish dbi:SQLite:/path/to/jonadab.sqlite
# Alternately, the sqlite3 command line tool should also work.

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
# GET BY DATE:        (Last 3 args optional.  Dates, if specified, must be formatted for the database already.)
#          @records = @{getrecordbydate(tablename, datefield, mindate, maxdate, maxfields)};
# DELETE:  $result  = deleterecord('tablename', $id);

use strict;
use Carp;
use DBI();
use DateTime::Format::SQLite;

sub DateTime::Format::ForDB {
  my ($dt) = @_;
  if (ref $dt) {
    $dt->set_time_zone("UTC");
    return DateTime::Format::SQLite->format_datetime($dt);
  }
  carp "Vogon Folk Music: $dt, $@$!";
}

sub DateTime::Format::FromDB {
  my ($string) = @_;
  my $dt = DateTime::Format::SQLite->parse_datetime($string);
  $dt->set_time_zone("UTC");
  return $dt;
}

my $db;
sub dbconn {
  # Returns a connection to the database.
  # Used by the other functions in this file.
  $db = DBI->connect("dbi:SQLite:dbname=$dbconfig::database", {'RaiseError' => 1})
    or die ("Cannot Connect (to $dbconfig::database): $DBI::errstr\n");
  return $db;
}

sub getnext {
  # NEXT:    $record =  getnext(tablename, field, oldvalue); # Returns a record with a value just greater than oldvalue in field.
  # NEXT:    $record =  getnext(tablename, field1, oldvalue, field2, value2) # Exclude records where field2 doesn't match this value.
  # Please note that if multiple records have the same value, only one of them is returned.
  my ($table, $field, $oldvalue, @more) = @_;
  my ($ef, $ev, @field, %fv);
  while (@more) {
    ($ef, $ev, @more) = @more;
    croak "getnext called with unbalanced arguments (no value for $ef field)" if not defined $ev;
    push @field, $ef;
    $fv{$ef} = $ev;
  }
  my $db = dbconn();
  my $query = qq[SELECT * FROM $table WHERE ]
                       . (join " AND ", ("$field > ?", map { "$_=?" } @field) )
                       . qq[ ORDER BY $field LIMIT 1];
  my @arg = ($oldvalue, map { $fv{$_} } @field);
  my $q = $db->prepare($query);
  $q->execute(@arg);
  return $q->fetchrow_hashref();
}
sub getlast {
  # LAST:    $record =  getlast(tablename, field); # Returns the record with the highest value in that field.
  # Please note that if multiple records have the same value, only one of them is returned.
  my ($table, $field, @more) = @_;
  my ($ef, $ev, @field, %fv);
  while (@more) {
    ($ef, $ev, @more) = @more;
    croak "getlast called with unbalanced arguments (no value for $ef field)" if not defined $ev;
    push @field, $ef;
    $fv{$ef} = $ev;
  }
  my $db = dbconn();
  my $conditions = join ' AND ', map { "$_=?" } @field;
  my $where = $conditions ? qq[ WHERE $conditions ] : '';
  my $q = $db->prepare(qq[SELECT * FROM $table $where ORDER BY $field DESC LIMIT 1]);
  $q->execute(map { $fv{$_} } @field);
  return $q->fetchrow_hashref();
}

sub finddateoverlap {
# OVERLAP: @records = finddateoverlap(tablename, startfield, endfield, startdt, enddt);
  my ($table, $sf, $ef, $sdt, $edt, @more) = @_;
  croak "finddateoverlap needs datetime objects to compare against" if not ref $sdt;
  croak "finddateoverlap needs datetime objects to compare against" if not ref $edt;
  my (%fv, @field, $field, $value);
  while (@more) {
    ($field, $value, @more) = @more;
    croak "finddateoverlap called with unbalanced arguments (no value for $field field)" if not defined $value;
    push @field, $field;
    $fv{$field} = $value;
  }
  my $db = dbconn();
  my $q = $db->prepare("SELECT * FROM $table WHERE "
                       . (join " AND ",
                          qq[$ef >= ?],
                          qq[$sf <= ?],
                          map { qq[$_=?] } @field ));
  $q->execute(DateTime::Format::ForDB($sdt),
              DateTime::Format::ForDB($edt),
              map { $fv{$_} } @field);
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub getsince {
# GETNEW:  @records =   getsince(tablename, datetimefield, datetimeobject);
  my ($table, $dtfield, $dt, $q) = @_;
  die "Too many arguments: getrecord(".(join', ',@_).")" if $q;
  my $when = DateTime::Format::ForDB($dt);
  my $db = dbconn();
  $q = $db->prepare("SELECT * FROM $table WHERE $dtfield >= ?");  $q->execute($when);
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    push @answer, $r;
  }
  return @answer;
}

sub getrecordbydate {
# GET BY DATE:        (Dates, if specified, must be formatted for the database already.)
#          @records = @{getrecordbydate(tablename, datefield, mindate, maxdate, maxfields)};
  my ($table, $field, $mindate, $maxdate, $maxfields, $q) = @_;
  die "Too many arguments: getrecordbydate(".(join', ',@_).")" if $q;
  die "Must specify either mindate or maxdate (or both) when calling getrecordbydate." if ((not $mindate) and (not $maxdate));
  die "Must specify date field when calling getrecordbydate." if not $field;
  #warn "DEBUG:  getrecordbydate(table $table, field $field, min $mindate, max $maxdate, maxfields $maxfields);";
  my $db = dbconn();
  my (@where, @arg);
  if ($mindate) {
    push @where, "$field >= ?";
    push @arg, $mindate;
  }
  if ($maxdate) {
    push @where, "$field <= ?";
    push @arg, $maxdate;
  }
  $q = $db->prepare("SELECT * FROM $table WHERE " . (join " AND ", @where) . ";");  $q->execute(@arg);
  my (@r, $r);
  while ($r = $q->fetchrow_hashref()) { push @r, $r; }
  if ($maxfields and @r > $maxfields) {
    # Fortuitously, DB-formatted datetime strings generally sort correctly when sorted ASCIIbetically:
    @r = sort { $$a{$field} <=> $$b{$field} } @r;
    if ($maxdate and not $mindate) {
      # If only the maxdate is specified, we want the _last_ n items before that:
      @r = @r[(0 - $maxfields) .. -1];
    } else {
      # Otherwise, take the first n:
      @r = @r[1 .. $maxfields];
    }
  }
  return \@r;
}

sub getrecord {
# GET:     %record  = %{getrecord(tablename, id)};
# GETALL:  @recrefs = getrecord(tablename);     # Don't use this way on enormous tables.
  my ($table, $id, $q) = @_;
  die "Too many arguments: getrecord(".(join', ',@_).")" if $q;
  my $db = dbconn();
#  eval {
    $q = $db->prepare("SELECT * FROM $table".(($id)?" WHERE id = ?":""));  $q->execute($id?($id):());
#  }; use Carp;  croak() if $@;
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub changerecord {
  # Used by updaterecord.  Do not call directly; use updaterecord instead.
  my ($table, $id, $field, $value) = @_;
  my $db = dbconn();
  my $q = $db->prepare("update $table set $field=? where id='$id'");
  my $answer;
  eval { $answer = $q->execute($value); };
  carp "Unable to change record ($table, $id, $field, $value): $@" if $@;
  return $answer;
}

sub updaterecord {
# UPDATE:  @changes = @{updaterecord(tablename, $record_as_hashref)};
# See end of function for format of the returned changes arrayref
  my ($table, $r, $f) = @_;
  die "Too many arguments: updaterecord(".(join', ',@_).")" if $f;
  die "Invalid record: $r" if not (ref $r eq 'HASH');
  my %r = %{$r};
  my $o = getrecord($table, $r{id});
  die "No such record: $r{id}" if not ref $o;
  my %o = %{$o};
  my @changes = ();
  foreach $f (keys %r) {
    if ($r{$f} ne $o{$f}) {
      my $result = changerecord($table, $r{id}, $f, $r{$f});
      push @changes, [$f, $r{$f}, $o{$f}, $result];
    } else {
      push @changes, ["Not changed: $f", $r{$f}, $o{$f}, ''] if $main::debug > 2;
    }
  }
  return \@changes;
  # Each entry in this arrayref is an arrayref containing:
  # field changed, new value, old value, result
}

sub addrecord {
# ADD:     $result  = addrecord(tablename, $record_as_hashref);
  my ($table, $r, $f) = @_;
  croak "Too many arguments: addrecord(".(join', ',@_).")" if $f;
  croak "Incorrect argument: record must be a hashref" if not ('HASH' eq ref $r);
  my %r = %{$r};
  croak "Record must contain at least one field" if not keys %r;
  my $db = dbconn();
  my @field = sort keys %r;
  my @param = map { "?" } @field;
  my @value = map { $r{$_} } @field;
  my ($result, $q);
  eval {
    $q = $db->prepare("INSERT INTO $table (". (join ", ", @field) . ") "
                      . "VALUES (" .(join ", ", @param). ")");
    $result = $q->execute(@value);
  };
  if ($@) {
    use Data::Dumper;
    confess "Unable to add record: $@\n" . Dumper(@_);
  }
  if ($result) {
    $db::added_record_id = $db->func('last_insert_rowid'); # Calling code can read this magic variable if desired.
  } else {
    warn "addrecord failed: " . $q->errstr;
  }
  return $result;
}

sub countfield {
# COUNT:   $number  = countfind(tablename, fieldname);
  my ($table, $field, $startdt, $enddt, %crit) = @_;
  my $q;
  die "Incorrect arguments: date arguments, if defined, must be DateTime objects." if (defined $startdt and not ref $startdt) or (defined $enddt and not ref $enddt);
  die "Incorrect arguments: you must define both dates or neither" if (ref $startdt and not ref $enddt) or (ref $enddt and not ref $startdt);
  for my $criterion (keys %crit) {
    die "Incorrect arguments:  criterion $criterion specified without values." if not $crit{$criterion};
  }
  my $whereclause;
  if (ref $enddt) {
    my $start = DateTime::Format::ForDB($startdt);
    my $end   = DateTime::Format::ForDB($enddt);
    $whereclause = " WHERE fromtime > '$start' AND fromtime < '$end'";
  }
  for my $field (keys %crit) {
    my $v = $crit{$field};
    my $whereword = $whereclause ? 'AND' : 'WHERE';
    if (ref $v eq 'ARRAY') {
      $whereclause .= " $whereword $field IN (" . (join ',', @$v) . ") ";
    } else {
      warn "Skipping criterion of unknown type: $field => $v";
    }
  }
  my $db = dbconn();
  $q = $db->prepare("SELECT id, $field FROM $table $whereclause");
  $q->execute();
  my %c;
  while (my $r = $q->fetchrow_hashref()) {
    ++$c{$$r{$field}};
  }
  return \%c;
}

sub findsince {
  my ($table, $datetimefield, $dt, $field, $value, @more) = @_;
  my (%fv, @field);
  croak "findsince called with unbalanced arguments (no value for $field field)" if not defined $value;
  push @field, $field; $fv{$field} = $value;
  while (@more) {
    ($field, $value, @more) = @more;
    croak "findsince called with unbalanced arguments (no value for $field field)" if not defined $value;
    push @field, $field;
    $fv{$field} = $value;
  }
  my $when = DateTime::Format::ForDB($dt);
  my $db = dbconn();
  my $q = $db->prepare("SELECT * FROM $table WHERE $datetimefield >= ? AND " . (join " AND ", map { qq[$_=?] } @field ));
  $q->execute($when, map { $fv{$_} } @field);
  my (@answer, $r);
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub findnull {
  my ($table, $nullfield, @more) = @_;
  my (%fv, @field);
  my ($field, $value);
  while (@more) {
    ($field, $value, @more) = @more;
    croak "findnull called with unbalanced arguments (no value for $field field)" if not defined $value;
    push @field, $field;
    $fv{$field} = $value;
  }
  my $db = dbconn();
  my $q = $db->prepare("SELECT * FROM $table WHERE " .
                       (join " AND ", (qq[$nullfield IS NULL],
                                       map { qq[$_=?] } @field )));
  $q->execute(map { $fv{$_} } @field);
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub findrecord {
# FIND:    @records = findrecord(tablename, fieldname, exact_value [, fieldname, value, ...]);
  #my ($table, $field, $value, @more) = @_;
  my ($table, @more) = @_;
  my (%fv, @field, $field, $value);
  #croak "findrecord called with unbalanced arguments (no value for $field field)" if not defined $value;
  #push @field, $field; $fv{$field} = $value;
  my $caller = undef;
  while (@more) {
    ($field, $value, @more) = @more;
    if ($field eq '__CALLER__') {
      $caller = $value;
    } else {
      if (not defined $value) {
        warn "findrecord called by $caller" if defined $caller;
        croak "findrecord called with unbalanced arguments (no value for $field field)" if not defined $value;
      }
      push @field, $field;
      $fv{$field} = $value;
    }
  }

  my $db = dbconn();
  my $querytext = "SELECT * FROM $table WHERE " . (join " AND ", map { qq[$_=?] } @field );
  my $q;
  eval {
    $q = $db->prepare($querytext);
  };
  if ($@ or not $q) {
    warn "findrecord: encountered an error ($@) while constructing the query: querytext";
    warn "called as findrecord(@_)";
    #warn "findrecord was called by $caller" if defined $caller;
    return;
  }
  $q->execute(map { $fv{$_} } @field);
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub searchrecord {
# SEARCH:  @records = @{searchrecord(tablename, fieldname, value_substring)};
  my ($table, @criterion) = @_;
  my (@clause);
  while (@criterion) {
    my $f = shift @criterion;
    croak("searchrecord called with imbalanced arguments: no search value for field '$f'") if not @criterion;
    my $v = shift @criterion;
    my ($val) = $v =~ /((?:[A-Za-z0-9._]|-|\s)+)/;
    push @clause, qq[$f LIKE '%$val%'];
  }
  croak("searchrecord() called with no search criteria") if not @clause;
  my $whereclause = join " AND ", @clause;
  my $db = dbconn();
  #my $q = $db->prepare("SELECT * FROM $table WHERE $field LIKE '%$value%'");  $q->execute();
  my $q = $db->prepare("SELECT * FROM $table WHERE $whereclause");
  $q->execute();
  my @answer; my $r;
  while ($r = $q->fetchrow_hashref()) {
    if (wantarray) {
      push @answer, $r;
    } else {
      return $r;
    }
  }
  return @answer;
}

sub deleterecord {
# DELETE:  $result  = deleterecord('tablename', $id);
  my ($table, $id, $q) = @_;
  croak "Too many arguments: deleterecord(".(join', ',@_).")" if $q;
  $id = $$id{id} if ref $id; # In case the naughty programmer passes a hashref.
  croak "Invalid id argument to deleterecord" if not defined $id;
  my $db = dbconn();
  my $q = $db->prepare("DELETE FROM $table WHERE id = ?");
  $q->execute($id);
}

1;
