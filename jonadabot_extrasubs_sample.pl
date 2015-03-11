#!/usr/bin/perl
# -*- cperl -*-

# ircbot_extrasubs.pl is where installation-specific subroutines should be put.
logit("Loading extrasubs.");

our %routine = (
                trout => sub {
                  my ($trigger, %arg) = @_;
                  my ($trig, $target) = $arg{text} =~ m~^!(\w+)\s*(\w*)~;
                  my @alttarg = ($arg{sender}, 'Dudley', 'yourself', $arg{sender}, $irc{oper}, 'Rodney', $irc{oper}, $arg{sender});
                  my $zapbystander = getconfigvar($cfgprofile, 'zapbystander');
                  if ($zapbystander > 0) {
                    push @altarg, $irc{channel}{lc $arg{channel}}{nicks}[rand @{$irc{channel}{lc $arg{channel}}{nicks}}]
                      for 1 .. $zapbystander;
                  }
                  $target ||= $alttarg[int rand rand @alttarg];
                  $target = $arg{sender}  if $target eq 'me';
                  if (not grep { (lc $_) eq (lc $target) } @{$irc{channel}{lc $arg{channel}}{nicks}}) {
                    logit("!trout invalid target ($target) being redirected") if $debug{trout};
                    logit("!trout channel $arg{channel}", 3) if $debug{trout} > 1;
                    $target = $alttarg[int rand rand @alttarg];
                  } elsif (rand(100) < 7) {
                    logit("!trout choosing alternate target on a whim") if $debug{trout};
                    $target = $alttarg[int rand rand @alttarg];
                  }
                  $target = (getconfigvar($cfgprofile, 'botismale') ? "himself" : "herself")
                    if $target eq 'yourself';
                  my @verb = ('slaps', 'declines to slap', 'slaps', 'slaps', 'slaps', 'slaps',
                              'thwacks', 'whaps', 'smacks', 'smacks', 'beats', 'knocks',
                              'jostles', 'attacks', 'accosts', 'bothers', 'tickles');
                  my @num  = ('a', 'a', 'a', 'two', 'three', 'seven', '42', 'over nine thousand');
                  my @fshz = ('large', 'large', '', 'large', 'large', 'small', 'medium-sized', '', '');
                  my @fish = ('trout', 'trout', 'trout', 'trout', 'trout', 'bass', 'bass',
                              'walleye', 'bluegill', 'sunfish', 'muskie',
                              'pike', 'salmon', 'tuna', 'shark', 'blue whale', 'halibut', 'herring',
                              'barracuda', 'puffer fish', 'flounder', 'squid',
                              'channel cat', 'goldfish', 'carp', 'plecostomus', 'fish');
                  my %plfish = ( 'blue whale' => 'blue whales', 'shark' => 'sharks',
                                 'squid' => 'squids', 'channel cat', 'channel catfish',
                                 'muskie' => 'muskellunge', 'flounder' => 'flounders', );
                  my $num  = $num[int rand int rand @num];
                  my $fsh  = $fish[int rand int rand @fish];
                  my $msg  = "/me " . $verb[int rand rand @verb] . " $target around a bit with "
                    . (join " ", (grep { $_ } ($num, $fshz[int rand int rand @fshz],
                                               (($num eq 'a') ? $fsh : ($plfish{$fsh} || $fsh))
                                              ))) . ".";
                  return $msg;
                },
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
                      my $ch = $arg{channel}; # lexical closure
                      $irc{situationalregex}{$ch}{hangman} =
                        +{  enabled  => 1,
                            regex    => qr/^([a-z]|$word|details?|guess(?:es)?|state|letters?|bank)$/i,
                            callback => sub { my ($rekey, $txt, %x) = @_;
                                              my $response = $routine{hangman}->("situationalregex",
                                                                                 situation => $rekey,
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
                      delete $irc{situationalregex}{$arg{channel}};
                      return "$irc{oper} has shortened the rope!  You have been hanged!";
                    } else {
                      if ((index((lc $text), (lc $word)) >= 0)) {
                        $$srec{value} = "DONE:$word";
                        updaterecord('userpref', $srec);
                        delete $irc{situationalregex}{$arg{channel}};
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
                            delete $irc{situationalregex}{$arg{channel}};
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
                  #return '/me serves up a knuckle sandwich.';
                  my %nix = ( kosher => +{ never => ['pepperoni', 'bacon', 'ham', 'ham sandwiches', 'BLTs',
                                                     'tuna salad sandwiches', 'egg salad sandwiches', 'chicken salad sandwiches',
                                                     'ham salad sandwiches', 'bologna sandwiches', 'hot dogs', 'salami sandwiches',
                                                     'blood', 'garlic and blood', 'barbecue ribs', 'sweet and sour pork',
                                                     'stuffed peppers', 'enchilladas', 'stromboli', 'meatball stroganoff',
                                                     'deviled eggs', 'a full English breakfast',
                                                     (map { "$_ corpses" } ('killer bee', 'jackal', 'kobold',
                                                                            'soldier ant', 'jaguar', 'bat', 'gremlin',
                                                                            'orc', 'cave spider', 'wraith', 'human',
                                                                            'white unicorn', 'long worm',
                                                                            'green slime',),),
                                                    ],
                                           nomix => [[# meat
                                                      'fish sticks', 'fried chicken fingers', 'sausage', 'chicken',
                                                      'tuna', 'hamburgers', 'chicken sandwiches', 'beef burritos',
                                                      'chicken soft tacos', 'tacos',
                                                      # corpses aren't listed here, because they never get dairy toppings anyway
                                                     ],
                                                     [# dairy
                                                      'fried cheese sticks', 'vanilla ice cream', 'milk', "goat's milk",
                                                      'mayonnaise', 'mozzaraella cheese', 'tomato sauce, mozzarella cheese,',
                                                      'white sauce, mozzarella cheese',
                                                     ],],
                                         },
                              vegetarian => +{ never => ['pepperoni', 'bacon', 'ham', 'ham sandwiches', 'BLTs',
                                                         'tuna salad sandwiches', 'chicken salad sandwiches',
                                                         'ham salad sandwiches', 'bologna sandwiches', 'hot dogs',
                                                         'salami sandwiches', 'blood', 'garlic and blood',
                                                         'fish sticks', 'fried chicken fingers', 'sausage', 'chicken',
                                                         'tuna', 'hamburgers', 'chicken sandwiches', 'beef burritos',
                                                         'chicken soft tacos', 'tacos', 'beef stew', 'barbecue ribs',
                                                         'sloppy joe', 'sweet and sour pork', 'stuffed peppers',
                                                         'enchilladas', 'corned beef with apples', 'stromboli',
                                                         'meatball stroganoff', 'empanadas', 'deviled eggs',
                                                         'scrambled eggs', 'a full English breakfast',
                                                         (map { $_ . " corpses"}
                                                          ('rothe', 'giant', 'killer bee', 'jackal', 'dwarf', 'gnome',
                                                           'kobold', 'nymph', 'newt', 'soldier ant', 'floating eye',
                                                           'jaguar', 'bat', 'gremlin', 'mind flayer', 'leprechaun',
                                                           'stalker', 'mimic', 'orc', 'wumpus', 'cave spider',
                                                           'tengu', 'black dragon', 'wraith', 'human', 'troll',
                                                           'white unicorn', 'long worm', 'cockatrice'),),
                                                        ],
                                             },
                            );
                  logit("foodservice($trigger)");
                  $trigger =~ s/e?s$//;
                  $trigger =~ s/(hotdog|burger|hamburger|taco|burrito|wrap)/sandwich/;
                  $trigger =~ s/(cookie|cake|cupcake|pie|muffin|fudge|browni)e?s?/dessert/;
                  $trigger =~ s/^corpses?/nhcorpse/;
                  my @food = (qw(pizza sandwich dessert friedfood maindish nhcorpse milk veg sidedish breakfast water sushi water));
                  $trigger =~ s/^food/$food[int rand rand @food]/e;
                  #$trigger = 'maindish';
                  my %bev = (friedfood => +{ quantity => ['', 'a plate of', 'a basket of', 'a platter of', 'a bucket of', 'a whole passel of'],
                                             quality  => ['', 'fresh', 'hot', 'leftover'],
                                             theitem  => ['hash browns', 'chips', 'homefries', 'french fries',
                                                          'waffle fries', 'curly fries', 'sweet potato fries',
                                                          'fried cheese sticks', 'fish sticks', 'fried chicken fingers',
                                                          'deep fried twinkies', 'deep fried candy bars',
                                                          'fried eggrolls', 'deep-fried mushrooms', 'deep-fried broccoli',
                                                          'potato cakes', 'latkesim'],
                                             sweeten  => [''],
                                             flavors  => [''],
                                             toppings => ['cheddar cheese', 'lots and lots of salt', 'garlic salt',
                                                          'mozzarella', 'provalone',
                                                         ],
                                           },
                             water    => +{ quantity => ['', '', 'a glass of', 'a bottle of'],
                                            quality  => ['', '', 'cold', 'hot', 'tepid', '', ''],
                                            theitem  => ['water', 'water', 'tap water', 'spring water', 'mineral water', ],
                                            sweeten  => [''],
                                            flavors  => ['', '', '', 'lemon', ''],
                                            toppings => [''],
                                          },
                             maindish => +{ quantity => [''],
                                            quality  => ['', '', 'fresh', 'homemade', 'fresh', 'homemade', 'leftover', ''],
                                            theitem  => ['baked macaroni and cheese', 'cabbage rolls', 'quesadillas', 'hirseauflauf',
                                                         'sweet and sour pork', 'stuffed peppers', 'enchilladas', 'corned beef with apples',
                                                         'barbecue ribs', 'baked rigatoni', 'beef stew', 'stromboli', 'meatball stroganoff',
                                                         'scalloped potatoes', 'empanadas', 'borsch', 'bean soup', 'peanut butter stew',
                                                        ],
                                            sweeten  => [''],
                                            flavors  => ['', '', '', 'garlic'],
                                            toppings => [''],
                                          },
                             veg      => +{ quantity => [''],
                                            quality  => ['', '', '', 'fresh', 'steamed', 'glazed', 'broiled'],
                                            theitem  => ['broccoli', 'carrots', 'beets', 'corn on the cob',
                                                         'gazpacho', 'mixed vegetables', 'succotash', 'a vegetable platter',
                                                         'carrot sticks', 'celery sticks', 'sliced cucumber', 'snow peas',
                                                         'tomatoes', 'cherry tomatoes', 'yellow tomatoes', 'tomatillos',
                                                         'tossed salad', 'spinach salad', 'green salad',
                                                         'arugula', 'cabbage', 'brussels sprouts', 'watercress', 'endives', 'kale',
                                                         'leaf lettuce', 'iceberg lettuce', 'spinach', 'chard', 'kohlrabi', 'parsley',
                                                         'asparagus', 'eggplant', 'garlic cloves', 'avacado', 'okra', 'parsnips', 'turnips',
                                                         'bell peppers', 'sweet peppers', 'jalapenos', 'cayenne peppers', 'habanero peppers',
                                                         'bok choy', 'jama jama', 'bamboo', 'chicory', 'daikon', 'taro',
                                                         'leeks', 'pearl onions', 'scallions', 'shallots', 'quartered onions',
                                                         'chickpeas', 'black-eyed peas', 'fava beans', 'garbanzo beans', 'lentils',
                                                         'dandelion greens', 'turnip greens', 'collard greens', 'mustard greens', 'mixed greens',
                                                         'hominy', 'peas', 'green beans', 'wax beans', 'cauliflower', 'artichokes',
                                                         'lima beans', 'mushy peas', 'radishes', 'soybeans',
                                                        ],
                                            sweeten  => [''],
                                            flavors  => [''],
                                            toppings => [''],
                                          },
                             sidedish => +{ quantity => [''],
                                            quality  => ['', 'fresh', 'homemade'],
                                            theitem  => ['cole slaw', 'applesauce', 'deviled eggs', 'pilaf',
                                                         'buttermilk biscuits', 'oat bread rolls', 'corn pudding',
                                                         'macaroni salad',
                                                        ],
                                            sweeten  => [''],
                                            flavors  => ['', '', '', 'garlic'],
                                            toppings => [''],
                                          },
                             breakfast => +{ quantity => [''],
                                             quality  => [''],
                                             theitem  => ['scrambled eggs', 'pancakes', 'oatmeal waffles', 'apple fritters',
                                                          'hash browns', 'a full English breakfast', 'bacon',
                                                         ],
                                             sweeten  => [''],
                                            flavors  => ['', '', '', 'pepper'],
                                            toppings => [''],
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
                                                         'peanut butter sandwiches', 'BLTs', 'grilled cheese sandwiches', 'sloppy joe',
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
                             nhcorpse => +{ quantity => ['a stack of'],
                                            quality  => ['', '', 'rotten', 'partly eaten', 'fresh', ''],
                                            theitem  => [map { $_ . " corpses"}
                                                         ('rothe', 'giant', 'killer bee', 'lichen', 'blue jelly',
                                                          'jackal', 'dwarf', 'gnome', 'kobold', 'nymph', 'newt',
                                                          'soldier ant', 'floating eye', 'jaguar', 'bat', 'gremlin',
                                                          'gelatinous cube', 'mind flayer', 'leprechaun', 'stalker',
                                                          'mimic', 'orc', 'wumpus', 'cave spider', 'shrieker',
                                                          'tengu', 'black dragon', 'wraith', 'human', 'troll',
                                                          'white unicorn', 'long worm', 'green slime', 'cockatrice')],
                                            sweeten  => [''],
                                            flavors  => ['', '', '', '', '', 'tobasco sauce'],
                                            toppings => ['', '', '', '', '', 'garlic', 'blood', 'garlic and blood'],
                                          },
                            );
                  logit("foodservice revised trigger: $trigger");
                  my $diet = getircuserpref($arg{sender}, 'diet');
                  my $nix  = $nix{$diet} || +{ never => [], nomix => [[],[]], };
                  #$$nix{nomixa} = +{ map { $_ => 1 } $$nix{nomix}[0]};
                  #$$nix{nomixb} = +{ map { $_ => 1 } $$nix{nomix}[1]};
                  push @{$$nix{never}}, '__XXX__NEVER__XXX__';
                  my $maxretry = 50;
                  my @clause = map {
                    my $k = $_;
                    logit("foodservice key: $k", 4);
                    my $choice = '__XXX__NEVER__XXX__';
                    while (grep { ($choice) and ($choice eq $_) } @{$$nix{never}}) {
                      logit("$diet: never $choice", 6) unless $choice eq '__XXX__NEVER__XXX__';
                      if ($maxretry--) {
                        $choice = $bev{$trigger}{$k}[int rand rand @{$bev{$trigger}{$k}}];
                      } else {
                        $choice = '';
                      }
                    }
                    logit("choice: $choice", 5);
                    if (     grep { $_ eq $choice } @{$$nix{nomix}[0]}) {
                      logit("$diet: nomix A", 6);
                      push @{$$nix{never}}, $_  for @{$$nix{nomix}[1]}
                    } elsif (grep { $_ eq $choice } @{$$nix{nomix}[1]}) {
                      logit("$diet: nomix B", 6);
                      push @{$$nix{never}}, $_  for @{$$nix{nomix}[0]}
                    }
                    my $clause = $choice;
                    if ($k eq 'sweeten')  { $clause = "sweetened with $choice" if $choice; }
                    if ($k eq 'flavors')  { $clause = "flavored with $choice" if $choice; }
                    if ($k eq 'toppings') {
                      my $major = '';
                      if ((exists $bev{$trigger}{majortopping})
                          and (defined $bev{$trigger}{majortopping})
                          and not grep { $_ eq $bev{$trigger}{majortopping}
                                       } @{$$nix{never}}) {
                        $major = "$bev{$trigger}{majortopping} and ";
                        logit("major: $major", 6);
                        if (     grep { $_ eq $bev{$trigger}{majortopping}
                                      } @{$$nix{nomix}[0]}) {
                          logit("$diet: nomix A maj");
                          push @{$$nix{never}}, $_ for @{$$nix{nomix}[1]};
                        } elsif (grep { $_ eq $bev{$trigger}{majortopping}
                                      } @{$$nix{nomix}[1]}) {
                          logit("diet: nomix B maj");
                          push @{$$nix{never}}, $_ for @{$$nix{nomix}[0]};
                        }
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
                },

                vladsbane => sub {
                  my @buc  = (qw(blessed blessed uncursed cursed cursed cursed), '');
                  my @rust = ('rusty', 'very rusty', 'thoroughly rusty', 'rustproof', '');
                  my @corr = ('corroded', 'very corroded', 'thoroughly corroded', '', '');
                  my @burn = ('burnt', 'very burnt', 'fireproof', '', '');
                  my @ench = ('', '', '', '', '', '', '', '+0', '+0', '+0', '+0',
                              '+1', '+1', '+1', '+1', '-1', '-1', '-1',
                              '+2', '+3', '+5', '+7', '-2', '-3', '-4', '-5');
                  my @item =
                    (
                     ['dagger',     [@buc], [@rust, @corr, ''], [@ench], ['', 'orcish', 'crude'], ],
                     ['club',       [@buc], [@rust, @burn, ''], ['thonged', '', '', ''], ],
                     ["scalpel",    [@buc], [@rust, @corr, ''], [@ench], ],
                     ['tin opener', [@buc], [@rust, @corr, ''], ],
                     ["hands",      [],     ['bare', 'gloved'], ],
                     ['potion',     [@buc], ['diluted', ''], [qw(yellow milky smoky clear fizzy effervescent)], ],
                     ['icebox',     [@buc], [@rust, '', '', '', '', ''], [(('') x 15), 'full of corpses', 'full of booze'], ],
                     ['stone',      [@buc], [qw(gray gray gray gray whitegem greengem redgem bluegem blackgem luck load flint)]],
                    );
                  my @adj = @{$item[rand @item]};
                  my $baseitem = shift @adj;
                  my $answer = join ' ', grep { $_ } ((map { my @l = @{$_}; $l[rand @l] } @adj), $baseitem);
                  $answer =~ s/diluted clear/clear/;
                  $answer =~ s/(luck|load) (stone)/$1$2/;
                  $answer =~ s/gem / gem/;
                  if ((rand(30) > 28) and (not $answer =~ /hands|icebox/)) {
                    $num = 2 + int rand int rand int rand 5;
                    $answer = $num . " " . $answer . "s";
                  }
                  return $answer;
                },

                zap => sub {
                  my ($trigger, %arg) = @_;
                  my ($trig, $target) = $arg{text} =~ m~^!(\w+)\s*(\w*)~;
                  my @alttarg = ($arg{sender}, 'Dudley', 'yourself', $arg{sender}, $irc{oper}, 'Rodney', $irc{oper}, $arg{sender});
                  my $zapbystander = getconfigvar($cfgprofile, 'zapbystander');
                  if ($zapbystander > 0) {
                    push @altarg, $irc{channel}{lc $arg{channel}}{nicks}[rand @{$irc{channel}{lc $arg{channel}}{nicks}}]
                      for 1 .. $zapbystander;
                  }
                  $target ||= $alttarg[int rand rand @alttarg];
                  $target = $arg{sender}  if $target eq 'me';
                  $target = $irc{nick}[0] if $target eq 'yourself';
                  if (not grep { (lc $_) eq (lc $target) } @{$irc{channel}{lc $arg{channel}}{nicks}}) {
                    logit("!zap invalid target ($target) being redirected") if $debug{zap};
                    logit("!zap channel $arg{channel}", 3) if $debug{zap} > 1;
                    $target = $alttarg[int rand rand @alttarg];
                  } elsif (rand(100) < 13) {
                    logit("!zap choosing alternate target on a whim") if $debug{zap};
                    $target = $alttarg[int rand rand @alttarg];
                  }
                  my @wandappear = ('glass wand', 'oak wand', 'copper wand', 'aluminum wand', 'short wand', 'spiked wand',
                                    'balsa wand', 'ebony wand', 'silver wand', 'uranium wand', 'runed wand', 'jeweled wand',
                                    'crystal wand', 'marble wand', 'platinum wand', 'long wand', 'iron wand',
                                    'maple wand', 'tin wand', 'iridium wand', 'steel wand', 'curved wand',
                                    'pine wand', 'brass wand', 'zinc wand', 'hexagonal wand', 'forked wand',
                                    'grooved wand', 'gnarled wand', 'smooth wand', 'thin wand', 'thick wand',
                                    'polycarbonate wand', 'mithril wand', 'ceramic wand');
                  my @dcolor   = qw(red yellow green blue orange gray silver black white);
                  my @ncolor = qw(red black golden guardian);
                  my @polyform = ((map { "turns into a $_" } qw(newt lizard newt gecko newt newt newt newt newt newt)),
                                  (map { "feels like a new $_" } qw(man woman elf dwarf gnome orc automaton)),
                                  (map { "turns into a $_ dragon" } @dcolor),
                                  (map { "turns into a baby $_ dragon"} @dcolor),
                                  (map { "turns into a $_ naga"} @ncolor),
                                  (map { "turns into a baby $_ naga"} @ncolor),
                                  (map { "turns into a $_" } ('soldier ant', 'queen bee', 'quivering blob', 'cockatrice',
                                                              'werejackal', 'lynx', 'winged gargoyle', 'master mind flayer',
                                                              'blue jelly', 'mountain nymph', 'titanothere', 'woodchuck',
                                                              'scorpion', 'trapper', 'warhorse', 'purple worm', 'xan',
                                                              'vampire bat', 'forest centaur', 'fire elemental', 'shrieker',
                                                              'storm giant', 'titan', 'minotaur', 'vorpal jabberwock',
                                                              'demilich', 'ogre king', 'green slime', 'disenchanter',
                                                              'water moccasin', 'vampire lord', 'xorn', 'stone golem', 'salamander')),
                                  );
                  my @wandbank = (
                                  ['polymorph', 'beam', 'beam', $polyform[rand @polyform], 'resists'],
                                  ['polymorph', 'beam', 'beam', $polyform[rand @polyform], 'resists'],
                                  ['sleep', 'ray', 'sleep ray', 'falls asleep', 'yawns'],
                                  ['magic missile', 'ray', 'magic missile', 'dies', 'resists'],
                                  ['undead turning', 'beam', 'beam', 'suddenly comes alive', 'shudders in dread'],
                                  ['make invisible', 'beam', 'beam', 'disappears', 'resists'],
                                  ['striking', 'beam', 'wand', 'dies', 'resists'],
                                  ['cold', 'ray', 'ray of cold', 'chills out', 'feels mildly chilly'],
                                  ['fire', 'ray', 'ray of fire', 'is on fire', 'feels mildly warm'],
                                  ['death', 'ray', 'death ray', 'dies', 'resists'],
                                  ['slow monster', 'beam', 'beam', 'slows down', 'resists'],
                                  ['speed monster', 'beam', 'beam', 'speeds up', 'resists'],
                                  ['stoning', 'beam', 'beam', 'turns to stone', 'resists'],
                                  ['draining', 'beam', 'beam', 'seems less experienced', 'resists'],
                                  ['teleportation', 'beam', 'beam', 'disappears', 'resists'],
                                  ['incarceration', 'beam', 'beam', 'is arrested', 'escapes'],
                                  ['cancellation', 'beam', 'beam', 'is covered in sparkling lights', 'resists'],
                                  ['agony', 'beam', 'beam', 'writhes in agony', 'is unphased'],
                                  ['acid', 'ray', 'acid stream', 'screams', 'resists'],
                                  ['punishment', 'beam', 'beam', 'is punished', 'escapes'],
                                 );
                  my $appear = $wandappear[rand @wandappear];
                  my $wand = $wandbank[rand rand @wandbank];
                  $wand = $wandbank[0] if $trigger =~ /^poly/;
                  $wand = $wandbank[4] if $trigger =~ /^undead/;
                  logit("!zap random selection: $appear of $wand") if $debug{zap};
                  my $at = (grep { $_ eq $target } @{$irc{nick}})
                    ? (getconfigvar($cfgprofile, 'botismale') ? "at himself" : "at herself")
                    : qq[at $target];
                  my $msg = "/me zaps a " . ((rand(100) < 27) ? "wand of $$wand[0]" : $appear) . " $at.  ";
                  $msg =~ s/zaps a ([aeiou])/zaps an $1/;
                  if ((rand(100) < 40) and (not grep { $_ eq $target } @{$irc{nick}})) {
                    $msg .= "The $$wand[2] misses $target."
                  } elsif ((rand(100) < 35) and ($$wand[1] eq 'ray') and (not grep { $_ eq $target } @{$irc{nick}})) {
                    my @refl = ('armor', 'medallion', 'shield');
                    my $refl = $refl[rand @refl];
                    $msg .= "The $$wand[2] reflects off $target" . "'s $refl.";
                  } elsif ((rand(100) < 25)) {
                    $msg .= "$target $$wand[4].";
                  } else {
                    $msg .= "$target $$wand[3].";
                  }
                  return $msg;
                },
               );

