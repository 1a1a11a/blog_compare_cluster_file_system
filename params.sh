#!/bin/bash

# export CLUSTER_FS=beegfs
export CLUSTER_FS=ceph
# export CLUSTER_FS=mfs
export HOSTFILE=/tmp/host.$(date +%s)

export MASTER_IP=10.10.1.1
export CHUNK_SERVER_DISK_PATH=/disk/
export CLUSTER_FS_MOUNT_DIR=/mnt/cfs/
# export PASSWORD8=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c8 ; echo)


