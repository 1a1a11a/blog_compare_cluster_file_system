#!/bin/bash


# parse single-node experiments 
grep -A2 "all jobs" *.log|grep bw

# gather results from all nodes
mkdir logs/ 2>/dev/null;
for node in $(cat host); do 
    scp $node:'*.log' logs/
done

cd logs/
grep -A2 "all jobs" seqRead*.log|grep bw|awk '{print $3}'|tr -d [bw=MiB/s]|awk 'BEGIN{s=0;n=0}{s+=$1;n+=1}END{print s/n}'
grep -A2 "all jobs" seqRead*.log|grep bw
grep -A2 "all jobs" randRead*.log|grep bw
grep -A2 "all jobs" seqWrite*.log|grep bw
grep -A2 "all jobs" randWrite*.log|grep bw

