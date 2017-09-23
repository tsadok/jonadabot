#!/usr/bin/perl -w
# -*- cperl -*-

use HTML::Entities;

our $ourclan  = 'Splat';
our $tempdir  = '/b4/perl/nethack-junethack-unique-deaths-tempdir';
our $result   = '/var/www/nethack-stuff/deaths-needed.html';
our $altres   = '/var/www/nethack-stuff/deaths-obtained.html';
#our $pending  = '/b4/perl/nethack-junethack-bonemon-deaths.txt';

our $theclan  = $ourclan;
my  @clanarg  = grep { /^clan=/ } @ARGV;
if (@clanarg) {
  ($theclan)  = $clanarg[-1] =~ /^clan=(\w+)/;
  $result     = qq[/var/www/nethack-stuff/deaths-$theclan.html];
  $altres     = qq[/var/www/nethack-stuff/deaths-obtained-$theclan.html];
}

my %clanpage = ( # TODO: construct this list by scraping it from the junethack site.
                Corpses  => 'https://junethack.net/clan/Corpses',
                Cthulhus => 'https://junethack.net/clan/demiCthulhus',
                Determin => 'https://junethack.net/clan/Determination',
                Goons    => 'https://junethack.net/clan/GoonsInJune',
                IQUIT    => 'https://junethack.net/clan/IQUIT',
                Lichens  => 'https://junethack.net/clan/demilichens',
                Molds    => 'https://junethack.net/clan/SmileMold',
                Rolled   => 'https://junethack.net/clan/IROLLEDA3',
                SOR      => 'https://junethack.net/clan/SOR',
                Splat    => 'https://junethack.net/clan/TeamSplat',
                STDs     => 'https://junethack.net/clan/SlexuallyTransmittedDisease',
                unfoog   => 'https://junethack.net/clan/unfoog',
               );

my (%death, %clandeath);

use HTML::TreeBuilder;

for my $clan (keys %clanpage) {
  my $url = $clanpage{$clan};
  my $tempfile = qq[$tempdir/$clan.html];
  if ((not grep { /reparse/} @ARGV)
      and (($clan eq $theclan) or (not grep { /partial/ } @ARGV))) {
    unlink $tempfile;
    print "clan $clan: $url => $tempfile\n";
    system("wget", '--no-check-certificate', "-O", $tempfile, $url);
  } else {
    print "$clan: $tempfile\n";
  }
  my $tree = HTML::TreeBuilder->new;
  $tree->parse_file($tempfile);
  my @category = $tree->look_down( _tag  => 'div',
                                   class => qr/text_content/,
                                 );
  @cat = grep {
    my $outer  = $_;
    my @header = $outer->look_down( _tag => h2 );
    grep { /unique deaths/ } map { $_->as_HTML() } @header;
  } @category;
  for my $c (@cat) {
    my $gt = $c->look_down( _tag  => 'table',
                            class => qr/greytable/,
                          );
    my @tr = $gt->look_down( _tag => 'tr',
                             id   => qr/cell\d+/,
                           );
    my @td = map { my $tr = $_;
                   my @td = $tr->look_down( _tag => 'td' );
                   my @d  = map { $_->as_HTML(); } @td;
                   for my $d (@d) {
                     chomp $d;
                     if ($d =~ m/table_number/) {
                       # not a datum we need
                     } elsif ($d =~ m/<td>\s*Most/) {
                       # also not a datum we need
                     } else {
                       $death{__TOTAL__}{$d}++;
                       $death{$d}{$clan}++;
                       $clandeath{$clan}++;
                     }
                   }
                 } @tr;
  }
  sleep 1 unless grep { /reparse|partial/ } @ARGV;
}

#if (grep { /PENDING/ } @ARGV) {
#  $result =~ s/needed/needed-pending.html/;
#  $altres =~ s/obtained/obtained-pending.html/;
#  open PENDING, "<", $pending;
#  for my $p (grep { $_ and not $death{$_}{$ourclan}
#                  } map { chomp; qq[<td>$_</td>]
#                        } map {
#                          encode_entities($_)
#                        } <PENDING>) {
#    $death{__TOTAL__}{$p}++;
#    $death{$p}{$ourclan}++;
#    $clandeath{$ourclan}++;
#  }
#}

if (grep { /COUNTCATEGORIES/ } @ARGV) {
  print "\nTotal unique deaths:       " . (keys %death) . "\n\n";
  my @shk       = map { decode_entities($_) } grep { /shopkeeper/i } keys %death;
  my @shkmagmis = grep { /s magic missile/i } @shk;
  my @shkstrike = grep { /s wand/i } @shk;
  my @shkmelee  = grep { /shopkeeper(?!\S+s )/ } @shk;
  print "Shopkeeper-related deaths: " . @shk . "
      in melee:            " . @shkmelee . "
      wand (of striking):  " . @shkstrike . "
      magic missile:       " . @shkmagmis . "
      other:               " . ((scalar @shk) - (scalar @shkstrike) - (scalar @shkmagmis) - (scalar @shkmelee)) . "\n";
  my @wrath = grep { /the wrath of/i } keys %death;
  my $minionre = qr/(\w+ elemental|couatl|hezrou|marilith|\w+cubus|Aleax|\w+ devil) of ([A-Z]\w+)/i;
  my ($minion, %minion, %diety); for my $d (grep { $_ =~ $minionre } keys %death) {
    $d =~ $minionre;
    my ($min, $diety) = ($1, $2);
    $minion{$min}++; $diety{$diety}++; $minion++;
  }
  print "Divine Wrath:              " . @wrath
    . "\nDivine Minion:             " . $minion . "
     " . (join "\n     ", map { $_ . ((join "", map { " " } 1 .. (27 - length $_))) . $minion{$_}
                              } sort { $minion{$b} <=> $minion{$a} } keys %minion) . "\n";
  print "Dieties Represented:       " . (keys %diety) . "\n";

  my @rot  = grep { />poisoned by a rotted .*corpse/ } keys %death;
  my @dead = grep { />dead / } keys %death;
  print "Rotted Corpses:            " . @rot
    . "\nDead Monsters:             " . @dead . "\n";
  # TODO: (possibly racial) priests and priestesses of dieties, random monster's foo, rotted corpse of foo

  print "\n";
  exit 0;
}

if (grep { /DEBUG/ } @ARGV) {
  use Data::Dumper;
  print Dumper(\%death);
  exit 0;
}

my $maxclandeath = 0;
for my $c (keys %clandeath) {
  $maxclandeath = $clandeath{$c} if $clandeath{$c} > $maxclandeath;
}
my %threshhold = (
                  max => $maxclandeath,
                  our => $clandeath{$theclan},
                  not => int($clandeath{$theclan} / 5),
                 );
my %clanclass = map {
  my $k = $_;
  my $class = 'error';
  if ($k eq $theclan) {
    $class = 'ourclan';
  } elsif ($clandeath{$k} >= $threshhold{max}) {
    $class = 'firstplace';
  } elsif ($clandeath{$k} >= $threshhold{our}) {
    $class = 'ahead';
  } elsif ($clandeath{$k} > $threshhold{not}) {
    $class = 'behind';
  } else {
    $class = 'nothreat';
  }
  $k => $class;
} keys %clanpage;

my %classcnt;
for my $cln (sort { $clandeath{$b} <=> $clandeath{$a} } keys %clandeath) {
  #$classcnt{$cln} = ++$classcnt{$clanclass{$cln}};
  $classcnt{$cln} = 1;
}
for my $cls (qw(firstplace ahead ourclan behind nothreat)) {
  my $cnt = 1;
  for my $cln (sort { $clandeath{$b} <=> $clandeath{$a} } grep { $clanclass{$_} eq $cls} keys %clandeath) {
    $classcnt{$cln} = $cnt++;
  }
}
my %exclist;
my %exclusive = map { $_ => 0 } keys %clandeath;

my (@trow, @done, @both, $count);
for my $d (sort { $a cmp $b } grep { not /^__/ } keys %death) {
  #print "[$d] "; print "\n" if not ++$count % 5;
  my $clans = join ", ", map { qq[<span class="$clanclass{$_}$classcnt{$_}">$_</span>] } sort { $clandeath{$b} <=> $clandeath{$a} } keys %{$death{$d}};
  if ($death{$d}{$theclan}) {
    if (1 == scalar keys %{$death{$d}}) {
      ++$exclusive{$theclan};
      push @{$exclist{$theclan}}, $d;
    }
    push @done, qq[<tr>$d<td>$clans</td></tr>];
    push @both, qq[<tr>$d<td>$clans</td></tr>];
  } else {
    if (1 == scalar keys %{$death{$d}}) {
      my @clx = keys %{$death{$d}};
      ++$exclusive{$clx[0]};
      push @{$exclist{$clx[0]}}, $d;
    }
    push @trow, qq[<tr>$d<td>$clans</td></tr>];
    push @both, qq[<tr>$d<td>$clans</td></tr>];
  }
}

our @clancat = qw(firstplace ahead ourclan behind nothreat);
my  $us      = ($theclan eq $ourclan) ? 'Us' : $theclan;
our %catname = (
                firstplace => 'First Place',
                ahead      => 'Ahead of ' . $us,
                ourclan    => 'Our Clan',
                behind     => 'Behind ' . $us,
                nothreat   => 'No Threat',
               );
if ($threshhold{our} >= $threshhold{max}) {
  @clancat = qw(ourclan firstplace behind nothreat);
  $catname{firstplace} = 'Tied For First';
}
my $keytable = qq[<table class="key">
<thead><tr><th>category</th><th>clans (total deaths / exclusive deaths)</th></tr>
</thead><tbody>
  ] . (join "\n  ", map {
    our $cat = $_;
    my $catname = $catname{$cat} || $cat;
    (qq[<tr><td>$catname</td><td>] . (join ", ", map {
      my $cl = $_;
      qq[<span class="$clanclass{$cl}$classcnt{$cl}">$cl ($clandeath{$cl}/$exclusive{$cl})</span>]
    } sort {
      $clandeath{$b} <=> $clandeath{$a}
    } grep {
      $clanclass{$_} eq $cat
    } keys %clandeath) . qq[</td></tr>])
  } @clancat) . qq[\n
  </tbody></table>\n];

if (grep { /debug/ } @ARGV) {
  use Data::Dumper;
  print Dumper(+{ death => \%death});
}

my @alldeath = keys %{$death{__TOTAL__}};

use DateTime;
my $now = DateTime->now( time_zone => 'America/New_York' );
my $updated = qq[<div class="updated">Updated: ]
  . $now->month_abbr() . " " . $now->mday()
  . " at " . $now->hour() . ":" . $now->min()
  . " " . $now->time_zone_short_name()
  . "</div>";
$updated = '' if grep { /reparse|partial/ } @ARGV;

my $we  = ($theclan eq $ourclan) ? "we" : $theclan;
my $our = ($theclan eq $ourclan) ? "our" : $theclan . "'s";
open HTML, '>', $result;
print HTML qq[<html><head>
  <title>deaths needed for $theclan</title>
  <link rel="stylesheet" type="text/css" media="screen" href="deaths-needed.css" />
</head><body>
$updated
$keytable

<p>On the list below, <strong>deaths $we have already achieved are omitted</strong>.
   If you want to see a list that includes $our achievements, that is now
   <a href="deaths-obtained.html">available as a separate list</a>.</p>
<p>(If you just want to see which ones $we already have, see
   <a href="$clanpage{$theclan}">$our clan page on the junethack site</a>;
   the unique deaths list is near the end of the page.)</p>

  <table id="uniquedeaths"><thead>
  <tr><th>unique death</th><th>clans that have it</th></tr>
</thead><tbody>
  ] . (join "\n  ", @trow) . qq[
  <tr><td><strong>TOTAL</strong></td><td><strong>] . (scalar @alldeath) . qq[ unique deaths</strong></td></tr>\n
</tbody></table>

</body></html>];
close HTML;


$keytable = qq[<table class="key">
<thead><tr><th>category</th><th>clans (total deaths / exclusive deaths)</th></tr>
</thead><tbody>
  ] . (join "\n  ", map {
    our $cat = $_;
    my $catname = $catname{$cat} || $cat;
    (qq[<tr><td>$catname</td><td>] . (join ", ", map {
      my $cl = $_;
      my $ex = $exclusive{$cl} ? qq[<a href="#excl$cl">$exclusive{$cl}</a>] : $exclusive{$cl};
      qq[<span class="$clanclass{$cl}$classcnt{$cl}">$cl ($clandeath{$cl}/$ex)</span>]
    } sort {
      $clandeath{$b} <=> $clandeath{$a}
    } grep {
      $clanclass{$_} eq $cat
    } keys %clandeath) . qq[</td></tr>])
  } @clancat) . qq[\n
  </tbody></table>\n];

open HTML, '>', $altres;
print HTML qq[<html><head>
  <title>deaths obtained by each clan ($our perspective)</title>
  <link rel="stylesheet" type="text/css" media="screen" href="deaths-needed.css" />
</head><body>
$updated
$keytable

<p>On the list below, deaths $we have already achieved <strong>are included</strong>.
   There is also <a href="deaths-needed.html">the list of just the ones $we still need</a>.</p>
<p>(If you just want to see which ones $we already have, see
   <a href="$clanpage{$theclan}">$our
      clan page on the junethack site</a>; the unique deaths list is near the end of the page.)</p>

  <table id="uniquedeaths"><thead>
  <tr><th>unique death</th><th>clans that have it</th></tr>
</thead><tbody>
  ] . (join "\n  ", @both) . qq[
  <tr><td><strong>TOTAL</strong></td><td><strong>] . (scalar @alldeath) . qq[ unique deaths</strong></td></tr>\n
</tbody></table>

<hr />

] . (join "\n", map {
  my $cl = $_;
  qq[<div class="h"><a name="excl$cl">Exclusive deaths unique to
        <span class="$clanclass{$cl}$classcnt{$cl}">$cl</span></a> ($exclusive{$cl}): </div>
<div class="clanexclusive p">
  ] . (join qq[&nbsp;<span class="$clanclass{$cl}$classcnt{$cl}">/</span> ],
       map { qq[<span class="excldeath">$_</span>] }
       @{$exclist{$cl}}) . qq[</div>]
} sort {
  $clandeath{$b} <=> $clandeath{$a}
} keys %exclist) . qq[

</body></html>];
close HTML;
