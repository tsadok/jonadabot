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
} # TODO: support additional RDBMS options here
else {
  die "Unsupported/unknown/misspelled RDBMS: '$dbconfig{rdbms}'";
}

42;
