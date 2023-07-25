#!/bin/bash

set -euo pipefail
# set -x

BASE_DIR=$(dirname $(readlink -f $0));
source ${BASE_DIR}/params.sh;
export DEBIAN_FRONTEND=noninteractive


############################################################
# Help                                                     #
############################################################
help() {
    # Display Help
    echo "Script to install moosefs on a new master/chunkserver"
    echo
    echo "Syntax: script [-h|r]"
    echo "options:"
    echo "h     Print this Help."
    echo "v     Verbose mode."
    echo "r     role: master | chunkserver"
    echo
}

############################################################
# Main program                                             #
############################################################

while getopts h:r:v: flag; do
    case "${flag}" in
    r)
        role=${OPTARG}
        ;;
    h) help ;;
    v) echo "verbose is not supported" ;;
    esac
done

# setup the apt source
if [[ ! -f /etc/apt/sources.list.d/moosefs.list ]]; then
    # turn of overcommit to make fork easier
    echo 1 | sudo tee /proc/sys/vm/overcommit_memory

    wget -O - https://ppa.moosefs.com/moosefs.key | sudo apt-key add -
    echo "deb [arch=amd64] http://ppa.moosefs.com/moosefs-3/apt/ubuntu/focal focal main" | sudo tee /etc/apt/sources.list.d/moosefs.list
    sudo apt update
fi

# install moosefs
if [[ "${role}" == "master" ]]; then
    sudo apt install -yqq moosefs-master moosefs-cgi moosefs-cgiserv moosefs-cli
    sudo apt install -yqq moosefs-metalogger

    if [ ! -f /etc/mfs/mfsexports.cfg ]; then
        echo '*    /     rw,alldirs,admin,maproot=0:0' | sudo tee -a /etc/mfs/mfsexports.cfg
        echo '*    .     rw' | sudo tee -a /etc/mfs/mfsexports.cfg
        sudo touch /etc/mfs/mfstopology.cfg        
        sudo touch /etc/mfs/mfsmaster.cfg
    fi

    # start the master
    sudo mfsmaster -a start || true

    # setup the metalogger
    echo "MASTER_HOST = ${MASTER_IP}" | sudo tee -a /etc/mfs/mfsmetalogger.cfg
    sudo service moosefs-metalogger start

    # enable the web gui
    sudo service moosefs-cgiserv start

elif [[ "${role}" == "chunkserver" ]]; then
    echo '#####################' $(hostname) chunkserver '#####################'
    # install the chunkserver and client
    sudo apt install -yqq moosefs-chunkserver
    sudo apt install -yqq moosefs-client

    # setup the chunkserver
    echo '/disk/' | sudo tee -a /etc/mfs/mfshdd.cfg
    echo "MASTER_HOST = ${MASTER_IP}" | sudo tee -a /etc/mfs/mfschunkserver.cfg
    sudo chown -R mfs:mfs ${CHUNK_SERVER_DISK_PATH}
    sudo service moosefs-chunkserver start

    # setup the client
    sudo mkdir ${CLUSTER_FS_MOUNT_DIR}/ || true
    sudo mfsmount ${CLUSTER_FS_MOUNT_DIR} -H ${MASTER_IP}

else
    echo "unknown role: ${role}"
    exit 1
fi

# mfssetgoal -n 1 .


# stop the services 
# sudo umount /mnt/mfs
# sudo service moosefs-chunkserver stop
# sudo mfsmaster stop
# sudo service moosefs-metalogger stop
# sudo service moosefs-cgiserv stop
