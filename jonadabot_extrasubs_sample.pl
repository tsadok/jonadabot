#!/usr/bin/perl
# -*- cperl -*-

# ircbot_extrasubs.pl is where installation-specific subroutines should be put.

our %routine = (
                congrats => sub {
                  my ($player, $item) = @_;
                  my @congrat = ("Congrats, $player", "$player, Congrats!",
                                 "Way to go, $player!", "$player rocks!",
                                 'Woot!', 'Congratulations!', 'Yay!', 'Nice!', 'Go Team Demilichens!',
                                 'Awesome!', '^ You rock!');
                  return $congrat[rand @congrat];
                },
                ganbatte => sub {
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

