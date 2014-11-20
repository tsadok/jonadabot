#!/usr/bin/perl
# -*- cperl -*-

# ircbot_extrasubs.pl is where installation-specific subroutines should be put.

our %routine = (
                hangman => sub {
                  my ($trigger, %arg) = @_;
                  my $text = $arg{text};
                  my $context = ($arg{channel} eq 'private') ? $arg{sender} : $arg{channel};
                  my $srec  = findrecord('userpref', 'username', $context, prefname => 'hangmanstate');
                  my $state = (ref $srec) ? $$srec{value} : undef;
                  logit("!hangman [$context] ($$srec{id}) " . ($state ? $state : "undef")) if $debug{hangman} > 1;
                  if ((not $state) or ($state =~ /^DONE/)) { # start a new one
                    logit("!hangman: starting new game",3) if $debug{hangman};
                    my @wf = getconfigvar($cfgprofile, 'wordfile');
                    return "Sorry, $irc{oper} needs to install a wordfile to support that game." if not @wf;
                    my $word;
                    open WORDFILE, "<", $wf[rand @wf]; {
                      my @word = map { chomp; $_; } <WORDFILE>;
                      close WORDFILE;
                      $word = $word[rand @word];
                    }
                    if (not $word) {
                      logit("!hangman: no word found");
                      return "Failed to get a word, sorry.";
                    }
                    my $spacing = getircuserpref($arg{sender}, 'hangmanspacing');
                    $spacing = '' if not defined $spacing;
                    my $joiner = " "; $joiner = "" if ($spacing eq '0');
                    logit("joiner '$joiner', per spacing pref '$spacing' for user $arg{sender}") if $debug{hangman} > 3;
                    my $blanks = join $joiner, map { ($_ =~ /[a-z]/i) ? "_" : (($_ eq ',') ? '.' : $_ ) } split //, $word;
                    my $right  = "";
                    my $wrong  = "";
                    my $bank   = join "", 'a' .. 'z';
                    $state = join ",", ($blanks, $right, $wrong, $bank, $word);
                    if ($$srec{id}) {
                      $$srec{value} = $state;
                      updaterecord('userpref', $srec);
                    } else {
                      addrecord('userpref', +{ username => $context,
                                               prefname => 'hangmanstate',
                                               value    => $state,
                                             })
                    }
                    if ($arg{channel} ne 'private') {
                      my $nid = $arg{networkid}; # lexical closure
                      my $ch  = $arg{channel};   # lexical closure
                      $irc{situationalregex}{$nid}{$ch}{hangman} =
                        +{  enabled  => 1,
                            regex    => qr/^([a-z]|$word|details?|guess(?:es)?|state|letters?|bank)$/i,
                            callback => sub { my ($rekey, $txt, %x) = @_;
                                              my $response = $routine{hangman}->("situationalregex",
                                                                                 situation => $rekey,
                                                                                 networkid => $x{networkid},
                                                                                 channel   => $x{channel},
                                                                                 text      => qq[!hangman $txt],
                                                                                 sender    => $x{sender},
                                                                                );
                                              say($response, channel => $x{channel}, sender => $x{sender}, fallbackto => 'private');
                                            },
                         };
                    }
                    return "New Puzzle:  $blanks";
                  } else {
                    my ($blanks, $right, $wrong, $bank, $word) = split /[,]/, $state;
                    my $maxguesses = getconfigvar($cfgprofile, 'hangmanduration') || 8;
                    my $remaining  = $maxguesses - length $wrong;
                    logit("!hangman: mg $maxguesses, re $remaining, r<$right>, w<$wrong>",3) if $debug{hangman} > 2;
                    if ($remaining < 0) {
                      $$srec{value} = "DONE:$word";
                      updaterecord('userpref', $srec);
                      logit("!hangman: rope shortened",4);
                      delete $irc{situationalregex}{$arg{networkid}}{$arg{channel}};
                      return "$irc{oper} has shortened the rope!  You have been hanged!";
                    } else {
                      if ((index((lc $text), (lc $word)) >= 0)) {
                        $$srec{value} = "DONE:$word";
                        updaterecord('userpref', $srec);
                        delete $irc{situationalregex}{$arg{networkid}}{$arg{channel}};
                        return "Yep.";
                      } elsif ($text =~ /^!hangman (details|guesses|state)/) {
                        return "Guessed Right: $right; Guessed Wrong: $wrong; $remaining guesses left.";
                      } elsif ($text =~ /^!hangman (letters|bank)/) {
                        return "Unguessed letters: $bank";
                      } elsif ($text =~ /^!hangman\s*(?:guess)?\s*([a-z])$/i) { # Process guess
                        my $letter = $1;
                        logit("!hangman: guessing $letter",4) if $debug{hangman} > 3;
                        if (index((lc $right . lc $wrong), (lc $letter)) > 0) {
                          logit("!hangman: that's a repeat.", 5) if $debug{hangman} > 3;
                          return "You have already guessed $letter";
                        } elsif (index((lc $word), (lc $letter)) >= 0) {
                          # Correct Guess:
                          $right .= $letter;
                          $bank =~ s/$letter//i;
                          my %remains = map { (lc $_) => $_ } split //, $bank;
                          my $spacing = getircuserpref($arg{sender}, 'hangmanspacing');
                          $spacing = '' if not defined $spacing;
                          my $joiner = " "; $joiner = "" if ($spacing eq '0');
                          $blanks = join $joiner, map { $remains{lc $_} ? '_' : (($_ eq ',') ? '.' : uc $_) } split //, $word;
                          logit("joiner '$joiner', per spacing pref '$spacing' for user $arg{sender}") if $debug{hangman} > 3;
                          $$srec{value} = join ',', ($blanks, $right, $wrong, $bank, $word);
                          if (not ($blanks =~ /[_]/)) {
                            $$srec{value} = 'DONE';
                          }
                          updaterecord('userpref', $srec);
                          logit("!hangman: correct", 5), if $debug{hangman} > 3;
                          return "Correct:  $blanks";
                        } else {
                          # Incorrect Guess:
                          $wrong .= $letter;
                          $bank =~ s/$letter//i;
                          my @bodypart = qw(gallows head body arm arm leg leg hand hand foot foot eye eye nose mouth ear ear);
                          while ($maxguesses >= scalar @bodypart) { push @bodypart, 'piece of clothing'; }
                          logit("!hangman: incorrect", 5) if $debug{hangman} > 3;
                          if ($maxguesses < length $wrong) {
                            $$srec{value} = "DONE:$word";
                            updaterecord("userpref", $srec);
                            logit("!hanged", 6) if $debug{hangman};
                            delete $irc{situationalregex}{$arg{networkid}}{$arg{channel}};
                            return "/me draws a rope.  You have been hanged!";
                          } else {
                            my $bp = "a " . $bodypart[length $wrong];
                            $bp =~ s/^a ([aeiou])/an $1/i;
                            $$srec{value} = join ',', ($blanks, $right, $wrong, $bank, $word);
                            updaterecord("userpref", $srec);
                            logit("!hangman: $bp",6) if $debug{hangman};
                            return "/me draws $bp.";
                          }
                        }
                      } else {
                        logit("!hangman: reporting status", 5) if $debug{hangman};
                        my %remains = map { (lc $_) => $_ } split //, $bank;
                        my $spacing = getircuserpref($arg{sender}, 'hangmanspacing');
                        $spacing = '' if not defined $spacing;
                        my $joiner = " "; $joiner = "" if ($spacing eq '0');
                        $blanks = join $joiner, map { $remains{lc $_} ? '_' : (($_ eq ',') ? '.' : uc $_) } split //, $word;
                        logit("joiner '$joiner', per spacing pref '$spacing' for user $arg{sender}") if $debug{hangman} > 3;
                        return $blanks;
                      }
                    }
                  }
                },
                foodservice   => sub {
                  my ($trigger, %arg) = @_;
                  logit("foodservice($trigger)");
                  $trigger =~ s/e?s$//;
                  $trigger =~ s/(hotdog|burger|hamburger|taco|burrito|wrap)/sandwich/;
                  $trigger =~ s/(cookie|cake|cupcake|pie|muffin|fudge|browni)e?s?/dessert/;
                  my @food = (qw(pizza sandwich dessert pizza sandwich milk sushi friedfood));
                  $trigger =~ s/^food/$food[int rand rand @food]/e;
                  my %bev = (friedfood => +{ quantity => ['', 'a plate of', 'a basket of'],
                                             quality  => ['', 'fresh', 'hot', 'leftover'],
                                             theitem  => ['hash browns', 'chips', 'homefries', 'french fries',
                                                          'waffle fries', 'curly fries', 'sweet potato fries',
                                                          'fried cheese sticks', 'fish sticks', 'fried chicken fingers',
                                                          'deep fried twinkies', 'deep fried candy bars',
                                                          'fried eggrolls', 'deep-xfried mushrooms', 'deep-fried broccoli',
                                                          'potato cakes', 'latkesim'],
                                             sweeten  => [''],
                                             flavors  => [''],
                                             toppings => ['cheddar cheese', 'lots and lots of salt', 'garlic salt',
                                                          'mozzarella', 'provalone',
                                                         ],
                                           },
                             dessert => +{ quantity => ['', 'a dish of', 'a saucer of', 'a plate of', ''],
                                           quality  => ['', 'hot', 'fresh', ''],
                                           theitem  => ['chocolate cake', 'chocolate-chip cookies', 'pumpkin pie', 'cupcakes',
                                                        'brownies', 'fudge brownies', 'mint brownies', 'chocolate fudge',
                                                        'molasses cookies', 'raisin cookies', 'peanut butter cookies', 'oatmeal cookies',
                                                        'cranberry muffins', 'blueberry muffins', 'raspberry muffins', 'cinnamon rolls',
                                                        'angel-food cake', 'plum cake', 'carrot cake', 'fudge marble cake',
                                                        'ginger snaps', 'macaroons', 'lemon bar cookies', 'peanut-butter fudge',
                                                        'banana nut muffins', 'oatmeal muffins', 'bran muffins', 'apple muffins',
                                                        'apple pie', 'peach pie', 'rhubarb pie', 'strawberry pie', 'pecan pie',
                                                       ],
                                           sweeten  => [''],
                                           flavors  => [''], # baked in
                                           toppings => ['', '', '', '', 'vanilla ice cream', 'vanilla ice cream',
                                                        'chocolate', 'hot fudge', 'nuts', 'marshmallow fluff', 'mirengue'],
                                         },
                             milk => +{ quantity => ['a glass of', 'a tall glass of', 'a small glass of', ''],
                                        quality  => ['', '', 'cold', 'cold', 'hot', 'warm', 'condensed'],
                                        theitem  => ['milk', 'milk', 'milk', "goat's milk", "soy milk"],
                                        sweeten  => ['', '', '', '', 'sugar', 'sugar', 'honey', 'aspartame', 'molasses'],
                                        flavors  => ['', 'chocolate', 'chocolate', '', 'vanilla', 'nutmeg', 'strawberry syrup'],
                                        toppings => [''],
                                      },
                             pizza => +{ quantity => ['a slice of', '', '', 'three slices of', 'two slices of'],
                                         quality  => ['', '', 'thin crust', 'deep dish', 'pan'],
                                         theitem  => ['pizza'],
                                         sweeten  => [''],
                                         flavors  => ['', '', 'garlic', 'basil', 'oregano', 'habanero pepper seed extract',],
                                         toppings => ['pepperoni', 'mushrooms', '', 'sausage', 'bacon', 'pineapple', 'ham',
                                                      'olives', 'bell peppers', 'onions', 'hot peppers', 'chicken',
                                                      'broccoli', 'mayonnaise', 'corn', 'tuna', 'seaweed', # Pizza Hut Japan has all the ones on this line on their menu.  Really.
                                                     ],
                                         majortopping => ((rand(100)>12) ? 'tomato sauce, mozzarella cheese,' : 'white sauce, mozzarella cheese,'),
                                       },
                             sushi => +{ quantity => ['', 'a plate of', ''],
                                         quality  => ['vegetarian', 'vegan', 'heavily Americanized'],
                                         theitem  => ['sushi'],
                                         sweeten  => [''],
                                         flavors  => [''],
                                         toppings => ['', 'aonori', 'cucumber', 'eggplant'],
                                       },
                             sandwich => +{ quantity => ['', 'a plate of', 'a tray of', 'a dozen', ''],
                                            quality  => ['', '', 'hot', 'cold', 'fresh', 'leftover', 'specialty hand-made', ''],
                                            theitem  => ['hamburgers', 'submarine sandwiches', 'ham sandwiches', 'chicken sandwiches',
                                                         'peanut butter sandwiches', 'BLTs', 'grilled cheese sandwiches',
                                                         'bean burritos', 'beef burritos', 'chicken soft tacos', 'tacos',
                                                         'tuna salad sandwiches', 'egg salad sandwiches', 'chicken salad sandwiches',
                                                         'ham salad sandwiches', 'cucumber sandwiches', 'cress sandwiches',
                                                         'bologna sandwiches', 'hot dogs', 'salami sandwiches', 'sandwiches',
                                                        ],
                                            sweeten  => [''],
                                            flavors  => [''],
                                            toppings => ['', '', '', 'lettuce', 'pickle', 'sweet pickle', 'dill pickle', 'onion',
                                                         'ketchup', 'mustard', 'mayonnaise', 'relish', 'hot peppers', 'green olives',
                                                         'cilantro', 'salsa', 'picante sauce', 'pico de gallo', 'salsa verde',
                                                         'southwest-style salsa', 'mango salsa',
                                                         'chutney', 'brown sauce', 'vegemite', 'parsley', 'cabbage',
                                                        ],
                                          },
                            );
                  logit("foodservice revised trigger: $trigger");
                  my @clause = map {
                    my $k = $_;
                    logit("foodservice key: $k", 4);
                    my $choice = $bev{$trigger}{$k}[int rand rand @{$bev{$trigger}{$k}}];
                    logit("choice: $choice", 5);
                    my $clause = $choice;
                    if ($k eq 'sweeten')  { $clause = "sweetened with $choice" if $choice; }
                    if ($k eq 'flavors')  { $clause = "flavored with $choice" if $choice; }
                    if ($k eq 'toppings') {
                      my $major = '';
                      if ((exists $bev{$trigger}{majortopping}) and (defined $bev{$trigger}{majortopping})) {
                        $major = "$bev{$trigger}{majortopping} and ";
                        logit("major: $major", 6);
                      }
                      $clause = "topped with $major$choice" if $choice;
                    }
                    logit("clause: $clause", 6);
                    $clause;
                  } qw(quantity quality theitem sweeten flavors toppings);
                  logit("foodservice clauses: " . @clause . ".", 3);
                  @clause = grep { $_ } @clause;
                  logit("foodservice non-empty clauses: " . @clause . ".", 3);
                  logit("foodservice clause: $_", 4) for @clause;
                  my $answer = "/me serves up " . (join " ", @clause) . ".";
                  logit("foodservice returning: $answer");
                  return $answer;
                },
                congrats => sub { # useful as followup from a logfile regex callback
                  my ($player, $item) = @_;
                  my @congrat = ("Congrats, $player", "$player, Congrats!",
                                 "Way to go, $player!", "$player rocks!",
                                 'Woot!', 'Congratulations!', 'Yay!', 'Nice!', 'Go Team Demilichens!',
                                 'Awesome!', '^ You rock!');
                  return $congrat[rand @congrat];
                },
                ganbatte => sub { # useful as followup from a logfile regex callback
                  my ($player, $item) = @_;
                  my @ganbatte = ("Go, go, $player!", "Go $player!",
                                  "^ gogogo",  "Go, go, go!", "The High Priest of Moloch is going down!",
                                  "Reach for the sky!", "Next stop, the Planes!",
                                  "Get the Amulet!", "Seek the Amulet of Yendor!",
                                  "Ganbattekudasai!", "^ Lookitthat", "Go Team Demilichens!",
                                 );
                  return $ganbatte[rand @ganbatte];
                }
               );

