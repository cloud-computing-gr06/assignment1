#!/bin/bash

PACKAGE=$(dpkg-query -W --showformat='${Status}\n' "sysbench"|grep "install ok installed")
if [ "" = "$PACKAGE" ]; then
    sudo apt -qq update 2> /dev/null | grep 'nothinggg' && sudo apt -qq install -y sysbench 2> /dev/null | grep 'nothinggg'
fi

TIME=$(date "+%s") # get timestamp

CPU=$(sysbench cpu --time=60 run | grep 'events per second' | awk '{print $4}') # run cpu speed benchmark
MEM=$(sysbench memory --time=60 --memory-block-size=4K --memory-total-size=100T run | grep 'MiB/sec' | awk '{print $4}') # run memory access benchmark

sysbench fileio --file-num=1 --file-total-size=1G prepare > /dev/null # create test files for benchmarks below
RNDREAD=$(sysbench fileio --file-num=1 --file-total-size=1G --file-test-mode=rndrd --time=60 run | grep 'read, MiB/s' | awk '{print $3}') # run random access disk read speed benchmark
SEQREAD=$(sysbench fileio --file-num=1 --file-total-size=1G --file-test-mode=seqrd --time=60 run | grep 'read, MiB/s' | awk '{print $3}') # run sequential access disk read speed benchmark
sysbench fileio --file-num=1 --file-total-size=1G cleanup | grep 'nothingggg' # delete test files

# print result
echo "$TIME"",""$CPU"",""$MEM"",""$RNDREAD"",""$SEQREAD" | sed 's/(//g'
