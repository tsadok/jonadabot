#!/usr/bin/perl

# The functions in this file are so general-purpose that they may
# reasonably be used when the rest of the IRC bot is not loaded, e.g.,
# in setup scripts.  Nothing in this file is allowed to have any
# dependencies beyond what the core Perl language provides.

sub commalist {
  my (@item) = @_;
  return if not @item;
  return join " and ", @item if 2 >= scalar @item;
  my $last = pop @item;
  return ((join ", ", @item) . ', and ' . $last);
}

sub uniq {
  my (%seen);
  return grep { not $seen{$_}++ } @_;
}

sub max {
  my $max = undef;
  for my $val (@_) {
    if ((not defined $max) or ($max < $val)) {
      $max = $val;
    }}
  return $max;
}

42;
