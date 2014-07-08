#!/usr/bin/perl
# -*- cperl -*-

our $cfgprofile = ((grep { $_ } map { /^cfgprofile=(\w+)/; $1 } @ARGV), 'jonadabot')[0];
print "Using config profile: $cfgprofile\n";

do "jonadabot_db.pl";

my @color = getconfigvar($cfgprofile, 'nickcolor');

print "Loaded " . @color . " colors.\n";

my $outfile;
for my $arg (grep { /^outfile=/ } @ARGV) {
  $arg =~ /^outfile=(.*)/;
  $outfile = $1;
}
$outfile ||= 'backscroll-color-demo.html';

open HTML, ">", $outfile;
print HTML qq[<html><head>\n  <title>backscroll nick color demo</title>\n  <link rel="stylesheet" type="text/css" media="screen" href="arsinoe.css" />\n</head><body>\n<table class="irc"><tbody>\n];
my $count;
my %special = ( 1 => 'Audience (First Defined Color)',
                2 => 'The Bot Itself (Color 2) ',
                3 => 'Primary Bot Operator (3)',
                4 => 'Persons with Master Privileges (4)',
                5 => 'Sibling Bots (5)',
              );
for my $color (@color) {
  $count++;
  my $colorname = $special{$count} ? $special{$count} : qq[Nick Color $count];
  my $hour = int($count / 60);
  my $min  = sprintf "%02d", ($count % 60);
  my $message = loremipsum($count);
  print HTML qq[<tr><td class="time irctime">$hour:$min UTC</td><th class="ircnick" style="color: $color;">$colorname</th><td class="ircmessage">$message</td></tr>\n];
}
print HTML qq[</tbody></table>\n</body></html>];
close HTML;


sub loremipsum {
  my ($seed) = @_;
  my @prefab = ( "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore.",
                 "The quick brown fox jumped over lazy dogs.",
                 "Et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi.",
                 "Now is the time for all good men to come to the aid of their country.",
                 "Ut aliquip ex ea commodo consequat.",
                 "Etaoin SHRDLU.",
                 "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
                 "Ecannot snation ed, canl heedani naldiedi ere. Iti rat... wec an her, rfitteh erehi ound.",
                 "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                 "Blah, blah, blah, blah, blahblah, blah blahblah, blahblah, Blah.",
                 "Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune...",
               );
  return $prefab[$seed % (scalar @prefab)];
}
