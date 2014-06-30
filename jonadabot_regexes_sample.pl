
# This is just a sample, for example purposes.  You should make a copy,
# ircbot_regexes.pl, and edit the copy to suit your purposes.

%watchregex = (
               # Top-level keys here are the "watch keys", as used in
               # the watchkeys field of the popwatch table and also in
               # the matchstring field of the logfilewatch table.

               # Any given POP3 mailbox or watched logfile can have any
               # number of these watch keys assigned to it.  The same
               # watch keys can be assigned to multiple mailboxes or
               # logfiles, so it's a many-to-many relationship.

               # The general format is [ key => [ subkeyone => qr/regex/, 'biffaction', [fieldlist], callback ],
               #                                [ subkeytwo => qr/match/, 'biffaction', [fieldlist], callback ],
               # biffaction is only relevant for watch keys that may be assigned to email accounts.
               #         possible biffactions include 'mention' (the default), 'readsubject', 'readbody'
               # fieldlist is relevant for watch keys that may be assigned to log files or have a callback.
               #         the listed fields should be in the same order the regex captures them in
               #         currently the only field with special meaning is 'player', which is checked
               #         against clan membership roles to determine if the message is relevant; however,
               #         all of them will be used to construct name => value pairs for the callback.
               # callback, if specified, will be treated as a coderef and called any time there's a match.
               #         As arguments, it will be passed the whole line followed by name/value pairs.
               #         If called by biff because of an email match, the named values will be owner
               #         (the irc nick of the mailbox owner) and possibly others in the future.
               #         If called due to a log file line match, the name/value pairs will be based
               #         on the field list and the match variables in the regex.
               #         Either way, if the callback returns a string, the match is considered good,
               #         and the returned string will be sent following the matched line.  If the
               #         callback returns 1, only the matched matched line will be sent.  If the
               #         callback returns false, the matched line will NOT be sent (it will be
               #         considered a no-good match).  Thus, the regex can match things that you
               #         don't necessarily really want to match, and the callback can reject them.

               nethack => [# For example, this watch key might be assigned to any email account where you
                           # might receive email about NetHack (and would want to be notified right away).

                           [ VanillaBug => qr/Subject[:].*(C|SC|W|X|L|M|Q|CE|S)(341|342|343)-(\d+)/ ],
                           [ NH4Trac    => qr/From[:].*scshunt+nh4.csclub[.]uwaterloo[.]ca/, 'readsubject' ],
                          ],

               test =>     [ # intended for testing the biff functionality
                            [ testone => qr/Subject[:].*jonadabot biff test (one|1)/, 'notify', ],
                            [ testtwo => qr/Subject[:].*jonadabot biff test (two|2)/, 'readsubject', ],
                            [ three   => qr/Subject[:].*jonadabot biff test (three|3)/, 'readbody', ],
                            [ four    => qr/Subject[:].*jonadabot biff test (four|4)/, 'callback', [],
                              sub { my ($line, %arg) = @_;
                                    return "regex callback test: $arg{owner}";
                              }],
                            [ logtwo  => qr/jonadabot (log) test (two|2)/, undef, [qw(ttype tnum)], ],
                            [ logthr  => qr/jonadabot (log) test (three|3)/, undef, [qw(ttype tnum)], ],
                            [ logfour => qr/jonadabot (log) test (four|4)/, undef, [qw(ttype tnum)],
                              sub { my ($line, %arg) = @_;
                                    return " n/v pairs: " . join "; ", map { $_ . " => " . $arg{$_} } keys %arg;
                                  } ],
                           ],

               Rodney => [# This watch key is designed to be assigned to an irssi logfile of #nethack
                          [ Death  => qr/Rodney.*?((\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)], (\d+) points, T:(\d+), (.*))/,
                                      undef, [qw(majorpart player score turn killer)],
                            sub { my ($line, %matchvar) = @_;
                                  if (isclanmember($matchvar{player})) {
                                    if ($matchvar{killer} eq 'ascended') {
                                      return $matchvar{majorpart}, $routine{congrats}->(); # match and followup
                                    } else { return $matchvar{majorpart}; } # just match
                                  } else { return; } # no match after all, this is not one of our players
                                },],
                          [ Wish   => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] wished for ["]([^"]*)["], on turn (\d+)/,
                                      undef, [qw(player wish turn)],
                            sub { return isclanmember($matchvar{player}) ? $matchvar{majorpart} : undef }],
                          [ AoLS   => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] averted death, on turn (\d+)/,
                                      undef, [qw(player turn)],
                            sub { return isclanmember($matchvar{player}) ? $matchvar{majorpart} : undef } ],
                          [ Achiev => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] (performed the invocation|entered the Planes), on turn (\d+)/,
                                      undef, [qw(player achievement turn)],
                            sub {
                              if (isclanmember($matchvar{player})) {
                                return $matchvar{majorpart}, $routine{ganbatte}->();
                              } else {
                                return;
                              }}, ],
                        ],
               xlog =>     [# This doesn't read an xlogfile directly.
                            # Instead, it reads the output of a support script.
                            # This one is intended for clan-relevant deaths only.
                            [ Death => qr/[<]\s*(\w+)\s*[>]\s+(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)], (\d+) points, T:(\d+), (.*)/,
                              undef, [qw(variant player score turn killer)],
                              sub { my ($line, %matchvar) = @_;
                                    if (findrecord('clanmembersrvacct', 'serveraccount', $matchvar{player})) {
                                      if ($matchvar{killer} =~ /ascended/) {
                                        return $routine{congrats}->();
                                      } else { return 1; }
                                    } else { return; }
                                  }, ],
                            ],
               xlogfile => [# This one is intended to read an xlogfile directly, for announcing all the deaths on
                            # a channel, much like Rodney does; but it is only VERY lightly tested.
                            # This is an unusual case because pretty much EVERY line is expected to match.
                            [xlogfile => qr/^version=([^:])[:]/, ],
                            undef, ['version'],
                            sub { my ($line, %matchvar) = @_;
                                  my %val  = map { /([^=]+)=(.*)/; ($1, $2)  } split /[:]/, $line;
                                  my %bfstring;
                                  my %bitfield = (conduct => +[ # order matters
                                                               'foodless', 'vegan', 'vegetarian', 'atheist',
                                                               'weaponless', 'pacifist', 'illiterate', 'polyitemless',
                                                                'polyselfless', 'wishless', 'artiwishless', 'genoless',
                                                              ],
                                                  achieve => [ 'Bell', 'Gehennom', 'Candelabrum', 'Book',
                                                               'Invocation', 'Amulet', 'Endgame', 'Astral',
                                                               'Ascended', 'Luckstone', 'Sokoprize', 'Medusa',
                                                             ],);
                                  my %obsoletedby = ( vegetarian  => 'vegan',
                                                      vegan       => 'foodless',
                                                      wishless    => 'artiwishless',
                                                      Gehennom    => 'Invocation',
                                                      Bell        => 'Invocation',
                                                      Book        => 'Invocation',
                                                      Candelabrum => 'Invocation',
                                                      Invocation  => 'Amulet',
                                                      Amulet      => 'Endgame',
                                                      Endgame     => 'Astral',
                                                      Astral      => 'Ascended',
                                                    );
                                  for my $bf (@bitfield) {
                                    my @bit    = unpack((join '', map { 'b1' } 1 .. scalar @{$bitfield{$bf}}), $val{$bf});
                                    my @bfitem = grep { $_ } map { $bit[$_] ? $bitfield{$bf}[$_] : undef } 0 .. ((scalar @bit) - 1);
                                    $val{"all_$bf"} = join ' ', @bfitem;
                                    my %isobs; for my $i (@bfitem) {
                                      $isobs{$i}++ if $obsoletedby{$i} and grep { $_ eq $isobsoletedby{$i} } @bfitem;
                                    }
                                    @bfitem = grep { not $isobs{$_} } @bfitem;
                                    $val{"notobs_$bf"} = join ' ', @bfitem;
                                  }
                                  my $showcond = ($val{death} =~ /ascended|celestial/) ? qq[ $val{notobs_conduct}] : '';
                                  my $showach  = ($val{death} =~ /ascended|celestial/) ? '' : qq[$val{notobs_achieve}, ];
                                  return qq[$val{$name} ($val{role} $val{race} $val{gender} {$val{align}}), DL$val{deathlev}/$val{maxlvl}, $showach$val{points} points, T:$val{turns}, $val{death}$showcond];
                            },
                           ],


              );

