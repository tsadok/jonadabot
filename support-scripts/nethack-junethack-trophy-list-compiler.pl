#!/usr/bin/perl -w
# -*- cperl -*-

our $ourclan  = 'demilichens';
our $clansdir = '/b4/perl/nethack-junethack-unique-deaths-tempdir';
our $result   = '/var/www/nethack-stuff/trophies-needed.html';

our (%trophy, %variantorder);

my %clanpage = (
                demilichens     => 'https://junethack.de/clan/demilichens',
                blackjack       => 'https://junethack.de/clan/BlackjackAndHookers',
                goons           => 'https://junethack.de/clan/Goonsinjune',
                justice         => 'https://junethack.de/clan/Justice',
                oldskul         => 'https://junethack.de/clan/OldSkul',
                s_mold          => 'https://junethack.de/clan/Smile_Mold',
                snap            => 'https://junethack.de/clan/Snap',
                splat           => 'https://junethack.de/clan/TeamSplat',
                wicked          => 'https://junethack.de/clan/WiCked',
                yetanother      => 'https://junethack.de/clan/YAJNHC',
                hi              => 'https://junethack.de/clan/hi',
                overcaffeinated => 'https://junethack.de/clan/overcaffeinated',
               );

use HTML::TreeBuilder;

my $clanurl  = $clanpage{$ourclan};
my $clanfile = qq[$clansdir/$ourclan.html];
if (not grep { /reparse/} @ARGV) {
  unlink $clanfile;
  print "clan $ourclan: $clanurl => $clanfile\n";
  system("wget", '--no-check-certificate', "-O", $clanfile, $clanurl);
  select undef,undef,undef,0.5;
} else {
  print "reading clan page: $clanfile\n";
}

my $tree = HTML::TreeBuilder->new;
$tree->parse_file($clanfile);

my @clmemb = $tree->look_down( _tag  => 'div',
                               class => qr/text_content/,
                               id    => qr/clan_members/,
                             );

my @ptbl = $clmemb[0]->look_down(
                                 _tag  => 'table',
                                 class => qr/clan_members/,
                                );

my @tr = $ptbl[0]->look_down(
                             _tag => 'tr',
                            );
my @member;
for my $tr (@tr) {
  my @m = map {
    my $anchor = $_;
    my $href   = $anchor->attr('href');
    my $name   = $anchor->as_trimmed_text();
    [ $name => $href ];
  } $tr->look_down( _tag => 'a', );
  push @member, @m;
}

my ($membercount, $trophycount, $variantcount) = (0,0,0);
for my $m (@member) {
  my ($name, $relurl) = @$m;
  my $absurl = "http://junethack.de" . $relurl;
  my $mfile  = $clansdir . $relurl . ".html";
  if (not grep { /reparse/} @ARGV) {
    unlink $mfile;
    print "member $name: $absurl => $mfile\n";
    system("wget", '--no-check-certificate', "-O", $mfile, $absurl);
    select undef,undef,undef,0.5;
  } else {
    print "reading member page: $mfile\n";
  }

  my $mtree = HTML::TreeBuilder->new;
  $mtree->parse_file($mfile);

  my @cab = grep {
    grep { $_->as_trimmed_text() =~ /Trophies/ } $_->look_down( _tag => 'h3' )
  } $mtree->look_down( _tag  => 'div',
                       class => qr/trophycabinet/,
                     );
  my @li = $cab[0]->look_down( _tag  => 'li' );
  for my $li (@li) {
    my $variant  = '[unknown variant]';
    $trophycount = 0;
    my @vardiv   = $li->look_down( _tag   => 'div',
                                   class => qr/trophyleft/);
    if (@vardiv) {
      $variant = $vardiv[0]->as_trimmed_text();
    }
    $variantorder{$variant} = ++$variantcount unless $membercount;
    my @imgl = $li->look_down( _tag  => 'a',
                               class => qr/imagelink/, );
    for my $imgl (@imgl) {
      my $relurl = $imgl->attr('href');
      my $absurl = "http://junethack.de" . $relurl;
      my ($title, $subtitle) = $imgl->attr('title') =~ /^(.*?)(?:[:](.*))?$/;
      $subtitle ||= '';
      my $imgelt = ($imgl->look_down( _tag => 'img' ))[0];
      my $imgsrc = $imgelt->attr('src');
      my $absimg = "http://junethack.de" . $imgsrc;
      my $needed = ($imgsrc =~ /light[.]png$/) ? 1 : 0;
      $trophy{$variant}{$title}{title}    = $title;
      $trophy{$variant}{$title}{subtitle} = $subtitle;
      $trophy{$variant}{$title}{webpage}  = $absurl;
      $trophy{$variant}{$title}{order}  ||= ++$trophycount;
      if ($needed) {
        $trophy{$variant}{$title}{icon} ||= $absimg;
      } else {
        $trophy{$variant}{$title}{icon} = $absimg;
        $trophy{$variant}{$title}{obtained}++;
        push @{$trophy{$variant}{$title}{clanmember}}, $name;
      }
    }
  }
  $membercount++;
}

#use Data::Dumper; print Dumper( +{ variantorder => \%variantorder, trophy => \%trophy });
#exit 0;

use DateTime;
my $now = DateTime->now( time_zone => 'America/New_York' );
my $updated = qq[<div class="updated">Updated: ]
  . $now->month_abbr() . " " . $now->mday()
  . " at " . $now->hour() . ":" . $now->min()
  . " " . $now->time_zone_short_name()
  . "</div>";
$updated = '' if grep { /reparse/ } @ARGV;

open HTML, ">", $result or die "Cannot write $result: $!";
print HTML qq[<html><head>
  <title>trophies for $ourclan</title>
  <link rel="stylesheet" type="text/css" media="screen" href="deaths-needed.css" />
</head><body>
$updated
<p>These are the trophies for clan $ourclan.  Brightly colored trophies have already
   been obtained: hover over them for a list of clan members who have the trophy.</p>
<p>The ones that are faded to white are still needed: hover over them for the
   trophy name and description.</p>
<table id="trophycase"><tbody>
   ] . (join "\n   ", map {
     my $variant = $_;
     qq[<tr><th>$variant</th>
            <td>] . ( join "\n                ", map {
              my $title = $_;
              my $tooltip; if ($trophy{$variant}{$title}{obtained}) {
                $tooltip = qq[$title: obtained by ] . join ", ", @{$trophy{$variant}{$title}{clanmember}};
              } else {
                $tooltip = qq[NEEDED: $title: $trophy{$variant}{$title}{subtitle}];
              }
              qq[<span class="trophyicon" title="$tooltip"><a href="$trophy{$variant}{$title}{webpage}"><img src="$trophy{$variant}{$title}{icon}" /></a></span>]
            } sort {
              $trophy{$variant}{$a}{order} <=> $trophy{$variant}{$b}{order}
            } keys %{$trophy{$variant}}) . qq[</td></tr>]
   } sort {
     $variantorder{$a} <=> $variantorder{$b}
   } keys %trophy) . qq[
</tbody></table>
</body></html>];
