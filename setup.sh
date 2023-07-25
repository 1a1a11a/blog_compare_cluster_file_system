#!/bin/bash

set -eux

####### parameters 
clusterFS=
# clusterFS=ceph
nNode=
hostfile=

BASE_DIR=$(dirname $0)


function usage() {
    echo "Usage: $0 [-c clusterFS] [-n nNode] [-h hostfile]"
}

function detect_node() {
    for i in $(seq 0 1000); do 
        if ping node${i} >> host; done
}

################### 
if [ -n "${hostfile:-}" ]; then
    if [ -f /var/emulab/boot/nodetype ]; then
        rm host 2>/dev/null || true
        for i in $(seq 0 ${nNode}); do echo node${i} >> host; done
    else
        echo "It looks like this is not on Cloudlab, please provide a file specifiying the nodes in the cluster,\
            each line is an IP or name of a node, the first line is the master node"
        exit
    fi
else
    cp ${hostfile} host;
fi

################### setup node ###################
sudo apt-get update && sudo apt-get install -yqq pssh;
parallel-ssh -h host -i -t 0 "sudo apt-get update && sudo apt-get install -yqq htop bmon wget";


################## setup clusterFS ###################
cd ${BASE_DIR}; 
bash ${clusterFS}_setup.sh -r master;


if [[ ${CLUSTER_FS} == "ceph" ]]; then
    for node in $(cat ${HOSTFILE}); do
        (
            ip=$(getent hosts $node | awk '{ print $1 }')
            ssh-copy-id -f -i /etc/ceph/ceph.pub $node;
            ssh $node """
                cd ${BASE_DIR}/clusterFS/ && bash ${CLUSTER_FS}_setup.sh -r chunkserver
            """
            sleep 240;
            sudo ceph orch host add $node ${ip} --labels _admin;
            sleep 240;
            ssh $node """
                sudo ceph orch apply osd --all-available-devices;
            """
        ) &
    done
    wait

    for j in `seq 1 4`; do 
        sleep 20; 
        echo $j; 
        sudo ceph -s || true;
    done

    sudo ceph fs volume create main;
    # use two-rep
    # sudo ceph config set global  mon_allow_pool_size_one true
    # sudo ceph osd pool set cephfs.main.data size 2 --yes-i-really-mean-it
    # sudo ceph osd pool set cephfs.main.data min_size 2
    sleep 120;
    sudo mount -t ceph admin@$(sudo ceph fsid).main=/ ${CLUSTER_FS_MOUNT_DIR}/;
    for node in $(cat ${HOSTFILE}); do
        ssh $node "sudo mount -t ceph admin@$(sudo ceph fsid).main=/ ${CLUSTER_FS_MOUNT_DIR}/"; 
        sudo chown -R $(whoami):$(whoami) ${CLUSTER_FS_MOUNT_DIR}/;
    done
elif [[ ${CLUSTER_FS} == "beegfs" ]]; then
    for node in $(cat ${HOSTFILE}); do
        scp /tmp/connauthfile ${node}:/tmp/connauthfile;
        ssh ${node} "cd ${BASE_DIR}/clusterFS/ && bash ${CLUSTER_FS}_setup.sh -r chunkserver;" &
    done
    wait
else
    cd ${BASE_DIR};
    parallel-ssh -h ${HOSTFILE} -i -t 0 """
        cd ${BASE_DIR}/clusterFS/ && bash ${CLUSTER_FS}_setup.sh -r chunkserver;
    """
fi


