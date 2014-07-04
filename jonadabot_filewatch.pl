#!/usr/bin/perl

print "Filewatch Debugging Level $debug{filewatch}\n" if $debug{filewatch};

sub watchlogfile {
  my ($log, $bwhash) = @_;
  my $pipe = $$bwhash{$$log{id}}{pipe};
  my $line = <$pipe>;
  my @watch = grep { not $$_{flags} =~ /X/ } findrecord("logfilewatch", "logfile", $$log{id});
  chomp $line;
  logit("watchlogfile($$log{mnemonic}, ...): $line") if $debug{filewatch} > 1;
  logit("" . @watch . " watch records found", 2) if $debug{filewatch} > 2;
  my ($whenseen, $expires, $note);
  for my $watch (@watch) {
    my ($ismatch, @followup);
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
          if (ref $callback) {
            my ($answer, @more) = $callback->($line, %matchvar);
            if ($answer eq 1) {
              $ismatch++;
              $note     ||= join ", ", @$fieldlist;
              logit("Callback returned 1, match but no followup") if $debug{filewatch} > 4;
            } elsif (not $answer) {
              logit("Callback returned false, no match") if $debug{filewatch} > 4;
            } else {
              $ismatch++;
              $note     ||= join ", ", @$fieldlist;
                push @followup, $_ for ($answer, @more);
                logit("Callback returned followup line(s).") if $debug{filewatch} > 4;
            }
          } else {
            $ismatch++;
            $note     ||= join ", ", @$fieldlist;
            logit("*** Regular expression match.", 5) if $debug{filewatch} > 2;
          }
        }
      }
    } else {
      $ismatch = (index($line, $$watch{matchstring}) >= 0) ? 1 : 0;
      my $did  = $ismatch ? "Matched" : "Did NOT match";
      $note  ||= $$watch{matchstring} . " (substring match)" if $ismatch;
      logit($did . qq[ substring, "$$watch{matchstring}"]) if $debug{filewatch} > 2;
    }
    if ($ismatch) {
      logit("Handling logfile watch match ($$watch{id}: $$watch{matchstring})", 3) if $debug{filewatch} > 3;
      $whenseen ||= DateTime::Format::ForDB(DateTime->now(@tz));
      $expires  ||= DateTime::Format::ForDB(DateTime->now(@tz)->add(days => 3));
      if ($$watch{nicktomsg}) {
        my $msg = ($$watch{msgprefix} ? "$$watch{msgprefix}: " : '') . $line;
        if (not findrecord('announcement', detail => $msg, context => $$watch{nicktomsg})) {
          warn "No nick to msg" if not $$watch{nicktomsg};
          say($msg, channel => 'private', sender => $$watch{nicktomsg});
          addrecord("announcement", +{ detail   => $msg,
                                       whenseen => $whenseen,
                                       expires  => $expires,
                                       context  => $$watch{nicktomsg},
                                       note     => $note,
                                     });
          logit("Sent /msg to $$watch{nicktomsg}") if $debug{filewatch} > 5;
        } else {
          logit("Already seen by $$watch{nicktomsg}") if $debug{filewatch} > 5;
        }
      }
      if ($$watch{channel}) {
        my $msg = ($$watch{chanprefix} ? "$$watch{chanprefix}: " : '') . $line;
        if (not findrecord('announcement', detail => $msg, context => $$watch{channel})) {
          say($msg, channel => $$watch{channel}, sender => $irc{oper}, fallbackto => 'private');
          # TODO: maybe add a flag to not fall back to private /msg
          logit("Echoed to $$watch{channel}") if $debug{filewatch} > 5;
          for my $followup (@followup) {
            say($followup, channel => $$watch{channel}, sender => $irc{oper}, fallbackto => 'private');
            logit("Following comment sent to $$watch{channel}") if $debug{filewatch} > 5;
          }
          addrecord('announcement', +{ detail   => $msg,
                                       whenseen => $whenseen,
                                       expires  => $expires,
                                       context  => $$watch{channel},
                                       note     => $note,
                                     });
        }
      }
    }
  }
}

42;
