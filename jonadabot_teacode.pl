sub tea {
  my (%arg) = @_;
  # tea( recipient => $recipient, channel => $howtorespond, sender => $sender );
  my $stepbystep = (defined $arg{stepbystep}) ? $arg{stepbystep}
    : 0;#((rand(100) > 95) ? 1 : 0);
  my @bev = ('black tea', 'green tea', 'herbal tea', 'white tea',
             'oolang tea', 'chocolate', 'chai', 'juice');
  my $bev = $arg{bev} || $bev[int rand int rand @bev];
  return juice(%arg) if $bev eq 'juice';
  print " * BEV: $bev\n" if $debug{tea} > 4;
  my %medium = (
                'black tea'  => ['water', 'water', 'milk', 'water', 'milk', 'industrial solvent'],
                'green tea'  => ['water', 'milk'],
                'herbal tea' => ['water'],
                'white tea'  => ['water'],
                'oolang tea' => ['water'],
                'chocolate'  => ['milk', 'milk', 'milk', "goat's milk", "soy milk", 'seal milk', ],
                'chai'       => ['milk', "water", "goat's milk", "soy milk", "industrial solvent", ],
               );
  my $medium = $medium{$bev}[int rand int rand scalar @{$medium{$bev}}];
  print " * MEDIUM: $medium\n" if $debug{tea} > 4;
  my $delivery; # This is important because it's relevant for other things,
                # including sentence structure and quantity.
  if ($arg{recipient}) {
    my @del = ('hands', 'gives', 'serves', 'offers', 'throws', 'tosses', 'foists', 'hoses', 'consumes');
    $delivery = $del[int rand int rand @del];
    if ($stepbystep and $delivery eq 'hoses') {
      $delivery = 'serves';
    }
  } else {
    $delivery = 'consumes';
  }
  print " * DELIVERY: $delivery\n" if $debug{tea} > 4;
  my ($container, $unit, $qtty);
  if ($delivery eq 'hoses') {
    $container = 'N/A'; # The sentence structure ignores this.
    my @unit   = ('thousand gallons', 'million gallons', 'billion gallons', 'trillion gallons',
                  'bazillion gallons', 'gazillion gallons', 'brazillion gallons',
                  'hillion jillion gallons', 'cubic AU', 'cubic parsecs', 'cubic light years');
    $unit = $unit[int rand int rand @unit];
    $qtty = 50 + int rand 950;
  } else {
    my @container = (
                     ['mug', [['ounces', 6, 32 ],
                              ['cups', 2, 6 ],
                              ['pint', 1, 1 ],
                              ['ml', 150, 750 ], ], ],
                     ['cup', [['ounces', 8, 8 ],
                              ['ml', 236, 237 ]]],
                     ['glass', [['ounces', 16, 64 ],
                                ['ml', 200, 500]]],
                     ['tankard', [['ounces', 24, 64 ],
                                  ['cups', 4, 8],
                                  ['ml', 400, 1000]]],
                     ['flagon', [['ounces', 32, 128],
                                 ['cups', 4, 32 ]]],
                     ['potion', [['ml', 50, 500],
                                 ['ounces', 8, 16]]],
                     ['cup', [['ounces', 8, 24 ],
                              ['ml', 200, 500 ]]],
                     ['thermos', [['ounces', 12, 16],
                                  ['ml', 350, 450],]],
                     ['flask', [['ml', 50, 2000],
                                ['ounces', 8, 32 ]]],
                     ['hogshead', [['gallons', 50, 65],
                                   ['litres', 200, 250], ]],
                    );
    my ($unitoptions);
    ($container, $unitoptions) = @{$container[int rand int rand @container]};
    my ($min, $max);
    ($unit, $min, $max) = @{$$unitoptions[int rand int rand @$unitoptions]};
    $qtty = $min + int rand ($max - $min);
  }
  if ($stepbystep or $debug{tea} > 5) {
    say("/me measures " . (join " ", grep { $_ } $qtty, $unit, "of", $medium) . ".", %arg);
  }
  my ($brewtemp, $heats, $brewed, $brews, $brewprep, $timeframe);
  if ($bev eq 'chocolate' or $medium =~ /milk/) {
    # All temperatures are specified here in kelvins and converted for display later.
    $brewtemp = 338 + int rand 34; # Between 150 and 211 degrees.
    $heats = 'heats';
    if ($bev eq 'chocolate') {
      ($brewed, $brews, $brewprep) = ('mixed', 'mixes', 'into');
    } else {
      ($brewed, $brews, $brewprep) = ('brewed', 'brews', 'in');
    }
  } elsif ($bev =~ /green|white|herbal/ and rand(100) < 70) {
    $brewtemp = 310 + int rand 62; # Between 100 and 211 degrees.
    $heats = 'heats';
    ($brewed, $brews, $brewprep) = ('brewed', 'brews', 'in');
  } else {
    my @heat = (
                ['heats', 310, 372, [['brewed', 'brews', 'in'],
                                     ['brewed', 'brews', 'in'],
                                     ['steeped', 'steeps', 'in'],
                                    ]],
                ['warms', 280, 309, [['steeped', 'steeps', 'in'],
                                     ['brewed', 'brews', 'in'],
                                     ['soaked', 'soaks', 'in'],
                                     ['infused', 'infuses', 'throughout'],
                                    ]],
                ['chills', 274, 280, [['soaked', 'soaks', 'in'],
                                      ['steeped', 'steeps', 'in'],
                                      ['marinated', 'marinates', 'in']
                                     ]],
                ['superheats', 373, 500, [['flash brewed', 'flash brews', 'in']] ],
                ['supercools', 3, 273, [['sublimated', 'sublimates', 'into']] ],
                ['superheats', 550, 2500, [['vapor-brewed', 'vaporizes', 'into']]],
               );
    my ($min, $max, $brewopts);
    ($heats, $min, $max, $brewopts) = @{$heat[int rand int rand int rand @heat]};
    $brewtemp = $min + int rand ($max - $min);
    ($brewed, $brews, $brewprep) = @{$$brewopts[int rand int rand int rand @$brewopts]};
  }
  if ($stepbystep or $debug{tea} > 5) {
    say("/me $heats the $medium to " . temperature($brewtemp) . ".", %arg);
  }
  if ($brewed eq 'mixed') {
    $timeframe = '';
  } else {
    if ($brews eq 'brews') {
      $timeframe = 15 + int rand 300;
      if ($timeframe > 95) {
        $timeframe = (2 + int rand int rand int rand 25) . " minutes";
      } else {
        $timeframe .= " seconds";
      }
      $timeframe = " for $timeframe";
    } elsif ($brews =~ /steeps|soaks/) {
      if (50 <= int rand 100) {
        $timeframe = ' overnight';
      } elsif (99995 <= int rand int rand 99999) {
        $timeframe = ' for all eternity';
      } else {
        my @tfunit = ('minutes', 'hours', 'days', 'weeks', 'months', 'years', 'decades', 'generations', 'centuries', 'millennia', 'million years', 'billion years', 'trillion years');
        my @tfnum  = ( 'seven', 'seven', 'seven', 3 .. 25 );
        $timeframe = ' for ' . $tfnum[int rand int rand @tfnum] . ' ' . $tfunit[int rand int rand int rand @tfunit];
      }
    }
  }
  say("/me $brews $bev $brewprep the $medium$timeframe.", %arg) if $stepbystep or $debug{tea} > 5;
  my ($sweetened, $flavored) = ('', '');
  if (75 >= int rand 100) {
    $sweetened = ", sweetened with ";
    my @sweetener = ('sugar', 'sugar', 'sugar', 'refined sugar',
                     'table sugar', 'white sugar', 'brown sugar',
                     'high-fructose corn syrup', 'molasses',
                     'honey', 'strained honey', 'filtered honey', 'raw honey', 'honeycomb',
                     'clover honey', 'orange blossom honey', 'wildflower honey', 'manuka honey',
                     'white grape juice concentrate', 'concentrated apple juice',
                     'saccharine', 'aspartame', 'sugar substitute', 'sucralose',
                     'a drop of his own blood',
                    );
    my $sweetener = $sweetener[int rand int rand @sweetener];
    say("/me adds $sweetener.\n", %arg) if $stepbystep or $debug{tea} > 5;
    $sweetened .= $sweetener;
    my @flavor;
    my %flavoropt = (
                     'black tea'  => ['vanilla extract', 'vanilla extract', 'lemon', 'cinnamon',
                                      'a vanilla bean', 'cloves', 'nutmeg', 'allspice', 'rosemary',
                                      'sage', 'thyme', 'fennel', 'anise', 'mace', 'chicory',
                                      'aged red cayenne pepper', 'habanero pepper seed extract',
                                      'peach juice','black raspberry extract', 'strawberry juice',
                                      'peanut oil', 'coffee grounds', ],
                     'green tea'  => ['ginger', 'ginger', 'cinnamon', 'star anise', 'allspice', ],
                     'chocolate'  => [undef, 'vanilla', 'peppermint',
                                      (2 + int rand int rand int rand int rand 17) . ' marshmallows'],
                    );
    my @fopt = @{$flavoropt{$bev} || []};
    while (35 >= int rand 100) {
      my $f = $fopt[int rand int rand @fopt];
      push @flavor, $f if $f;
    }
    $flavored = (scalar @flavor) ? ' and flavored with ' . commalist(uniq(@flavor)) : '';
  }
  my %detailedbev = (
                     'black tea' => [
                                     'black tea', 'black tea', 'black tea',
                                     'Lipton tea', # Just to make people cringe.
                                     'Darjeeling', 'Earl Grey', "Constant Comment",
                                     'English tea', 'Irish tea',
                                    ],
                     'herbal tea' => [
                                      'herbal tea', 'mint tea', 'orange tea', 'lemon tea',
                                      ('herbal blend #' . (1 + int rand int rand int rand 98)),
                                      'chamomile tea', 'sassafras tea', 'ginger tea',
                                      'pomegranate tea', 'raspberry tea',
                                      'guarana', 'yerba mate', 'tisane', 'yarrow tea',
                                      'peppermint tea', 'wintergreen tea', 'spearmint tea',
                                      'echinacea tea', 'ginseng tea', 'oksusu cha', 'pine tea',
                                     ],
                    );
  my $beverage;
  if ($bev eq 'chocolate') {
    $beverage = join " ", grep { $_ } 'hot chocolate' . $sweetened . $flavored;
    print " * DETAIL: CHOCOLATE\n" if $debug{tea} > 4;
  } elsif ($stepbystep) {
    print " * DETAIL: LESS\n" if $debug{tea} > 4;
    my %lessdetail = ( 'black tea'  => 'tea',
                       'green tea'  => 'tea',
                       'white tea'  => 'tea',
                       'oolang tea' => 'tea',
                     );
    $beverage = $lessdetail{$bev} || $bev;
  } elsif ($detailedbev{$bev}) {
    print " * DETAIL: MORE\n" if $debug{tea} > 4;
    my @detail = @{$detailedbev{$bev}};
    my $detail = $detail[int rand int rand @detail] || $bev;
    $beverage = join " ", grep { $_ } $detail,
      $brewed, $brewprep, $medium, "at", temperature($brewtemp) . $sweetened . $flavored;
  } else {
    print " * DETAIL: NORMAL\n" if $debug{tea} > 4;
    $beverage = join " ", grep { $_ } $bev,
      $brewed, $brewprep, $medium, "at", temperature($brewtemp) . $sweetened . $flavored;
  }
  if ($delivery eq 'hoses') {
    $arg{recipient} ||= 'himself';
    say("/me hoses $arg{recipient} down with "
      . (join " ", grep { $_ } $qtty, $unit, "of", $beverage) . ".", %arg);
  } else {
    say("/me pours the $bev into a $container.", %arg) if $stepbystep or $debug{tea} > 5;
    if ($delivery eq 'consumes') {
      my @verb = ("drinks", "drinks", "quaffs", "quaffs", "quaffs",
                  "consumes", "sips", "guzzles", "gulps down", "imbibes",
                  "swigs", "chugs", "swallows", "partakes of",
                  "inhales", "hoovers", "tosses down");
      my $verb = $verb[int rand int rand @verb];
      say("/me $verb a $container of $beverage.", %arg);
    } elsif ($delivery eq 'foists') {
      say("/me foists a $container of $beverage off on $arg{recipient}.", %arg);
    } elsif ($delivery eq 'throws') {
      my @verb = ("throws", "hurls", "lobs", "tosses");
      my $verb = $verb[int rand int rand @verb];
      my @prep = ("at", "to", "toward", "into", "through");
      my $prep = $prep[int rand int rand @prep];
      say("/me $verb a $container of $beverage $prep $arg{recipient}.", %arg);
    } else {
      say("/me $delivery $arg{recipient} a $container of $beverage.", %arg);
    }
  }
}

sub temperature {
  my ($kelvins) = @_;
  my @tempunit = ('degrees', "degrees Fahrenheit",
                  "degrees Celsius", "kelvins",
                  "Fahrenheit", "Celsius", "degrees Centigrade",
                  "degrees Kelvin", # I know it's wrong.  I don't care.  People say it this way.
                 );
  my $tempunit = $tempunit[int rand int rand @tempunit];
  if ($tempunit =~ /kelvin/i) {
    return $kelvins . " " . $tempunit;
  } elsif ($tempunit =~ /C/) {
    my $celsius = int($kelvins - 273);
    return $celsius . " " . $tempunit;
  } else {
    my $fahrenheit = int(($kelvins - 273) * 9/5 + 32);
    return $fahrenheit . " " . $tempunit;
  }
}

sub juice {
  my (%arg) = @_;
  $arg{recipient} ||= 'jonadab';
  my @fruit = ('apple', 'green apple', 'crabapple', 'peach', 'plum', 'quince', 'pear', 'nectarine', 'apricot',
               'cherry', 'black cherry', 'red cherry', 'white cherry', 'acerola', 'wild cherry',
               'orange', 'lemon', 'lime', 'tangerine', 'tangelo', 'pomelo', 'citron', 'clementine',
               'grapefruit', 'pink grapefruit', 'white grapefruit',
               'strawberry', 'blueberry', 'blackberry', 'raspberry', 'black raspberry', 'red raspberry',
               'cranberry', 'boysenberry', 'mulberry', 'huckleberry', 'hawberry', 'elderberry', 'gooseberry',
               'watermelon', 'cantaloupe', 'honeydew',
               'grape', 'white grape', 'concord grape', 'raisin', 'prune', 'fig', 'tamarind',
               'guava', 'kiwi', 'mango', 'papaya', 'passion fruit', 'pineapple', 'pawpaw', 'persimmon',
               'cayenne pepper', 'breadfruit', 'potato', 'onion', 'radish', 'dill pickle', 'loquat',
               'olive', 'habanero pepper seed', 'avacado', 'currant', 'kumquat', 'pumpkin', 'rambutan',
               'banana', 'coconut', 'cashew', 'pomegranate', 'starfruit', 'prickly pear', 'soursop', 'durian',
               'carrot', 'tomato', 'cucumber', 'celery', 'cabbage', 'watercress', 'rhubarb', 'zucchini',
               'nightshade', 'slime mold', 'death',
              );
  my $numoffruits = 1 + int rand int rand 3;
  my $fruits      = join " ", uniq(map { $fruit[rand @fruit] } 1 .. $numoffruits);
  my $juice       = $fruits . " juice";
  if (rand(100)<7) {
    $juice = "sour " . $juice;
  } elsif (rand(100)<8) {
    $juice = "sweet " . $juice;
  } elsif (rand(100)<9) {
    $juice = "cold " . $juice;
  } elsif (rand(100) < 5) {
    $juice = "hot " . $juice;
  }
  my @qtty = ("some ", "", "a glass of ", "a small glass of ", "a tall glass of ",
              "a cup of ", "a serving of ", "a vial of ", "a potion of ",
              "something that vaguely resembles ", qq[a juice box labeled ],
             );
  my $quantity = $qtty[int rand int rand @qtty];
  say("/me supplies $arg{recipient} with $quantity$juice.", %arg);
}
