#!/usr/bin/perl
# -*- cperl -*-

my $logfile = "/home/nathan/test.log";

sub logit {
  my ($string) = @_;
  open LOG, ">>", $logfile;
  print LOG $string . "\n";
  close LOG;
}

logit("Reading words file...");
open WORD, "<", "/usr/share/dict/words";
my @word = map { chomp; $_ } <WORD>;
close WORD;
logit("Words list assembled.");

sub randomphrase {
  my ($wc) = @_;
  return if $wc < 1;
  return join " ", map { $word[rand @word] } 1 .. $wc;
}

for my $number (qw(zero one two three four five six seven eight)) {
  print $number . $/;
  logit("jonadabot log test $number " . randomphrase(4));
  sleep 3;
}
