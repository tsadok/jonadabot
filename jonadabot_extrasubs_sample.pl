#!/usr/bin/perl
# -*- cperl -*-

# ircbot_extrasubs.pl is where installation-specific subroutines should be put.

our %routine = (
                foodservice   => sub { # makes a good custom trigger, e.g., a !food trigger
                  my ($trigger, %arg) = @_;
                  $trigger =~ s/e?s$//;
                  $trigger =~ s/hotdog|burger|hamburger|taco|burrito|wrap/sandwich/;
                  $trigger =~ s/cookie|cake|cupcake|pie|muffin|fudge|brownies/dessert/;
                  my @food = (qw(pizza sandwich dessert pizza sandwich milk sushi));
                  $trigger =~ s/^food/$food[int rand rand @food]/e;
                  my %bev = (dessert => +{ quantity => ['', 'a dish of', 'a saucer of', 'a plate of', ''],
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
                                           toppings => [''],
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
                                         toppings => ['pepperoni', 'mushroom', '', 'sausage', 'bacon', 'pineapple', 'ham',
                                                      'olives', 'bell peppers', 'onions', 'hot peppers', 'chicken',
                                                      'broccoli', 'mayonnaise', 'corn', 'tuna', 'seaweed', # Pizza Hut Japan has all the ones on this line on their menu.  Really.
                                                     ],
                                         majortopping => 'tomato sauce, mozzarella cheese,',
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
                  return "/me serves up " . (join " ", grep { $_ } map {
                    my $k = $_;
                    my $choice = $bev{$trigger}{$k}[int rand rand @{$bev{$trigger}{$k}}];
                    my $clause = $choice;
                    if ($k eq 'sweeten')  { $clause = "sweetened with $choice" if $choice; }
                    if ($k eq 'flavors')  { $clause = "flavored with $choice" if $choice; }
                    if ($k eq 'toppings') {
                      my $major = $bev{$trigger}{$k}{majortopping} ? "$bev{$trigger}{$k}{majortopping} and " : "";
                      $clause = "topped with $major$choice" if $choice;
                    }
                    $clause;
                  } qw(quantity quality theitem sweeten flavors)) . ".";
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

