#!/bin/bash

set -eu


BASE_DIR=$(dirname $(readlink -f $0));
source ${BASE_DIR}/params.sh;
export DEBIAN_FRONTEND=noninteractive


PASSWORD=1a1a11a
# public_ip=$(ifconfig|grep -A2 en|grep inet|head -n1|awk '{print $2}')
# public_ip=$(curl ifconfig.me)
public_ip=$(getent hosts $(hostname) | awk '{ print $1 }')
private_ip=$(getent hosts $(hostname -s) | awk '{ print $1 }')

sudo mkdir -p ${CLUSTER_FS_MOUNT_DIR} 2>/dev/null || true;


############################################################
# Help                                                     #
############################################################
help() {
    # Display Help
    echo "Script to install seaweedfs on a new master/chunkserver"
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

# update hostname because ceph hates FQDN 
sudo hostname $(hostname|cut -d . -f 1);

# clear the old disk because sometimes they cannot be recognized
node_type=$(cat /var/emulab/boot/nodetype);
if [[ "${node_type}" == r6525 || "${node_type}" == r650 ]]; then
    # sudo cephadm ceph-volume lvm zap --destroy /dev/nvme0n1
    sudo sgdisk --zap-all /dev/nvme0n1;
else 
    # sudo cephadm ceph-volume lvm zap --destroy /dev/sdb
    sudo sgdisk --zap-all /dev/sdb;
fi


# install ceph
if [[ "${role}" == "master" ]]; then
    echo '#########################' $(hostname) master
    sudo apt-get -yqq install podman cephadm net-tools >/dev/null;
    # sudo cephadm add-repo --release quincy
    sudo cephadm install ceph-common >/dev/null;

    sudo cephadm bootstrap --mon-ip ${MASTER_IP} --cluster-network 10.10.1.0/24 \
            --initial-dashboard-user $(whoami) --initial-dashboard-password ${PASSWORD} \
            --dashboard-password-noupdate --allow-overwrite
    sudo ceph cephadm get-pub-key >> ~/.ssh/authorized_keys
    sudo ceph cephadm set-user $(whoami)
    # sudo ceph orch daemon add osd node0:/dev/sdb;


elif [[ "${role}" == "chunkserver" ]]; then
    echo '#########################' $(hostname) chunkserver;
    sudo apt-get -yqq install podman cephadm net-tools >/dev/null;
    # sudo cephadm add-repo --release quincy
    sudo cephadm install ceph-common >/dev/null;
else
    echo "unknown role: ${role}"
    exit 1
fi


# sudo ceph orch host ls
# sudo ceph orch device ls
# sudo ceph osd stat
# sudo ceph osd status

# sudo cephadm ceph-volume lvm list

# sudo ceph health
# sudo ceph health detail

# sudo ceph status
# sudo ceph df
# sudo ceph osd ls
# sudo ceph osd pool ls
# sudo ceph osd pool get-quota cephfs.main.data

# sudo ceph orch host drain
# sudo ceph orch host rescan node2 --with-summary
# sudo ceph orch daemon add osd node0:/dev/sdb

# sudo cephadm shell

# ssh node1 """
#   vp=$(sudo lvdisplay|grep Path|tr -d ' ' | sed 's/LVPath//g'); echo -e 'y\n' | sudo lvremove ${vp};
#   sudo wipefs /dev/sdb -a;
#   sudo ceph orch apply osd --all-available-devices;
#   sudo ceph orch daemon add osd node0:/dev/sdb;
# """

