#!/bin/bash

export PERL_ANYEVENT_DEBUG_WRAP=1
perl jonadabot.pl
sleep 3
bash jonadabot-keeprunning.sh
