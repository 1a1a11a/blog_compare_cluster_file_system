#!/bin/bash

set -eu

CLUSTER_FS_MOUNT_DIR=/mnt/cfs/
parallel-ssh -h host -t 0 "sudo apt install -yqq fio;"


dd if=/dev/zero of=/mnt/cfs/fio.test.$(hostname -s) bs=1M count=840000
sleep 1200;


# measure sequential read bandwidth
echo '####################### sequential read start #########################';
fio --filename=/mnt/cfs/fio.test.$(hostname -s) --size=240GB --direct=1 --rw=read --bs=1m --ioengine=io_uring --iodepth=64 \
    --runtime=120 --numjobs=4 --time_based --group_reporting --name=seqRead > seqRead.log
echo '####################### sequential read finished #########################';
sleep 1200;


# measure random read IOPS
echo '####################### rand read start #########################';
fio --filename=/mnt/cfs/fio.test.$(hostname -s) --size=240GB --direct=1 --rw=randread --bs=4k --ioengine=io_uring --iodepth=64 \
    --runtime=120 --numjobs=4 --time_based --group_reporting --name=randRead > randRead.log
echo '####################### rand read finished #########################';
sleep 1200;


# measure sequential write bandwidth
echo '####################### sequential write start #########################';
fio --filename=/mnt/cfs/fio.test.$(hostname -s) --size=240GB --direct=1 --rw=write --bs=1m --ioengine=io_uring --iodepth=64 \
    --runtime=120 --numjobs=4 --time_based --group_reporting --name=seqWrite > seqWrite.log
echo '####################### sequential write finished #########################';
sleep 1200;


# measure random write IOPS
echo '####################### rand write start #########################';
fio --filename=/mnt/cfs/fio.test.$(hostname -s) --size=240GB --direct=1 --rw=randwrite --bs=4k --ioengine=io_uring --iodepth=64 \
    --runtime=120 --numjobs=4 --time_based --group_reporting --name=randWrite > randWrite.log
echo '####################### rand write finished #########################';
sleep 1200;





