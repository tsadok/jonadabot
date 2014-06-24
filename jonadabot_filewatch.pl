#!/usr/bin/perl

print "Filewatch Debugging Level $debug{filewatch}\n" if $debug{filewatch};

sub watchlogfile {
  my ($demi, $log, $bwhash) = @_;
  my %demilichen = %$demi;
  my $pipe = $$bwhash{$$log{id}}{pipe};
  my $line = <$pipe>;
  my @watch = grep { not $$_{flags} =~ /X/ } findrecord("logfilewatch", "logfile", $$log{id});
  chomp $line;
  logit("watchlogfile(..., $$log{mnemonic}, ...): $line") if $debug{filewatch} > 1;
  logit("" . @watch . " watch records found", 2) if $debug{filewatch} > 2;
  for my $watch (@watch) {
    my ($ismatch, $followup);
    if ($$watch{isregexkey}) {
      logit("Watch record is a regex key", 3) if $debug{filewatch} > 2;
      for my $watchitem (@{$watchregex{$$watch{matchstring}}}) {
        my ($watchkey, $regex, $biffaction, $fieldlist, $callback) = @$watchitem;
        logit("Attempting regular expression match ($watchkey).", 4) if $debug{filewatch} > 3;
        logit("Regular expression: $regex", 5) if $debug{filewatch} > 5;
        my %matchvar;
        if ($line =~ $regex) {
          # TODO: improve on this assignment:
          @matchvar{@$fieldlist} = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
          chomp $line;
          $ismatch++;
          $followup ||= $callback ? $callback->($line, \%matchvar) : undef;
          logit("*** Regular expression match.", 5) if $debug{filewatch} > 2;
        }
      }
    } else {
      $ismatch = (index($line, $$watch{matchstring})) ? 1 : 0;
      my $did = $ismatch ? "Matched" : "Did NOT match";
      logit($did . qq[ substring, "$$watch{matchstring}"]) if $debug{filewatch} > 2;
    }
    if ($ismatch) {
      logit("Handling logfile watch match", 3) if $debug{filewatch} > 3;
      if ($$log{nicktomsg}) {
        my $msg = ($$log{msgprefix} ? "$$log{msgprefix}: " : '') . $line;
        say($msg, channel => 'private', sender => $$log{nicktomsg});
        logit("Sent /msg to $$log{nicktomsg}") if $debug{filewatch} > 5;
      }
      if ($$log{channel}) {
        my $msg = ($$log{chanprefix} ? "$$log{chanprefix}: " : '') . $line;
        say($msg, channel => $$log{channel}, sender => $irc{oper}, fallbackto => 'private');
        # TODO: maybe add a flag to not fall back to private /msg
        logit("Echoed to $$log{channel}") if $debug{filewatch} > 5;
        if ($followup) {
          say($followup, channel => $$log{channel}, sender => $irc{oper}, fallbackto => 'private');
          logit("Following comment sent to $$log{channel}") if $debug{filewatch} > 5;
        }
      }
    }
  }
}

42;
