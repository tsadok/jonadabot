
my $workdir = "/b4/perl/xlogfiles";

my %xlog = ( NH4 => 'http://nethack4.org/xlogfile.txt' );

if (not grep { /reparse/ } @ARGV) {
  print "Retrieving xlog file(s)...\n";
  for my $k (keys %xlog) {
    system("wget", "-c", "-O", ($workdir . "/" . $k . "-xlog.txt"), $xlog{$k});
  }
}

print "Loading list of already-seen games...\n";
do "nethack-xlogfile-seen-games.pl";
my %seen = %{$$VAR1{seen}};

#print Dumper(+{ VAR1 => $VAR1, seen => \%seen});

print "Parsing xlog files...\n";
open LOG, ">>", "/var/log/nh4-RodneyStyle.log";
for my $k (keys %xlog) {
  print " * $k\n";
  open XLOG, "<", $workdir . "/" . $k . "-xlog.txt";
  while (<XLOG>) {
    chomp; my $line = $_;
    my %val;
    for my $pair (split /[:]/, $line) {
      my ($name, $value) = $pair =~ m/(.*?)=(.*)/;
      $val{$name} = $value;
    }
    my $gameid = join ":", $k, $val{name}, $val{birthdate}, $val{starttime}, $val{deathdate}, $val{endtime};
    if (not $seen{$gameid}) {
      my ($time) = localtime($val{endtime}) =~ /(\d+[:]\d+)/;
      print LOG "$time < $k > $val{name} ($val{role} $val{race} $val{gender} $val{align}), $val{points} points, T:$val{turns}, $val{death}\n";
      $seen{$gameid}++;
    }
  }
}

print "Saving list of seen games...\n";
use Data::Dumper;
open SEEN, ">", "nethack-xlogfile-seen-games.txt";
print SEEN Dumper(+{ seen => \%seen});
close SEEN;
system("mv", "nethack-xlogfile-seen-games.txt", "nethack-xlogfile-seen-games.pl");

print "Done.\n";
