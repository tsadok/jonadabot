
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
               #         as arguments, it will be passed the whole line followed by name/value pairs
               #         based on the field list and the match variables in the regex.  If it returns
               #         a string, that string will be sent along with (following) the matched line.

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
                          [ Death  => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)], (\d+) points, T:(\d+), (.*)/,
                                      undef, [qw(player score turn killer)], sub { my ($line, %matchvar) = @_;
                                                                                  if ($matchvar{killer} eq 'ascended') {
                                                                                    return $routine{congrats}->();
                                                                                  } else { return; }
                                                                                }, ],
                          [ Wish   => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] wished for ["]([^"]*)["], on turn (\d+)/,
                                      undef, [qw(player wish turn)]],
                          [ AoLS   => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] averted death, on turn (\d+)/,
                                      undef, [qw(player turn)], ],
                          [ Achiev => qr/Rodney.*?(\w+)\s*[(](?:[A-Z][a-z][a-z]\s*)+[)] (performed the invocation|entered the Planes), on turn (\d+)/,
                                      undef, [qw(player achievement turn)], sub { return $routine{ganbatte}->(); } ],
                        ],
              );
