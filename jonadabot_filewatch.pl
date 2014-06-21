#!/usr/bin/perl


sub watchlogfile {
  my ($demi, $log, $bwhash, $watches) = @_;
  my %demilichen = %$demi;
  my $pipe = $$bwhash{$$log{id}}{pipe};
  my $line = <$pipe>;
  my @watch = grep { not $$_{flags} =~ /X/ } findrecord("logfilewatch", "logfile", $$log{id});
  chomp $line;
  logit("watchlogfile(demi, $$log{mnemonic}, bwhash, watches): $line") if $debug{filewatch} > 1;
  for my $watch(@$watches) {
    my ($ismatch, $followup);
    if ($$watch{isregexkey}) {
      for my $watchitem (@{$watchregex{$$watch{matchstring}}}) {
        my ($watchkey, $regex, $biffaction, $fieldlist, $callback) = @$watchitem;
        my %matchvar;
        if ($line =~ $regex) {
          # TODO: improve on this assignment:
          @matchvar{@$fieldlist} = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
          chomp $line;
          $ismatch++;
          $followup ||= $callback ? $callback->($line, \%matchvar) : undef;
        }
      }
    } else {
      $ismatch = (index($line, $$watch{matchstring})) ? 1 : 0;
    }
    if ($ismatch) {
      if ($$log{nicktomsg}) {
        my $msg = ($$log{msgprefix} ? "$$log{msgprefix}: " : '') . $line;
        say($msg, channel => 'private', sender => $$log{nicktomsg});
      }
      if ($$log{channel}) {
        my $msg = ($$log{chanprefix} ? "$$log{chanprefix}: " : '') . $line;
        say($msg, channel => $$log{channel}, sender => $irc{oper}, fallbackto => 'private');
        # TODO: maybe add a flag to not fall back to private /msg
        if ($followup) {
          say($followup, channel => $$log{channel}, sender => $irc{oper}, fallbackto => 'private');
        }
      }
    }
  }
}

42;
