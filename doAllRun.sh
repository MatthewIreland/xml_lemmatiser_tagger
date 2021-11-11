#!/bin/bash

cd run

if [ -f log.txt ]; then
   nowtime=$( date +%s )
   mv log.txt log_$nowtime.txt
fi

./allrunPar.sh -n1 > log.txt
