#!/bin/bash
set -eu

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
if [[ ! -d /mnt/ext4ramdisk/beegfs ]]; then
    sudo wget -q -O - https://www.beegfs.io/release/beegfs_7.3.4/gpg/GPG-KEY-beegfs | sudo apt-key add - >/dev/null
    sudo wget https://www.beegfs.io/release/beegfs_7.3.4/dists/beegfs-jammy.list -O /etc/apt/sources.list.d/beegfs.list

    sudo apt-get update >/dev/null
    sudo apt-get install -yqq apt-transport-https >/dev/null;
    sudo apt-get install -yqq beegfs-mgmtd beegfs-meta beegfs-storage beegfs-client beegfs-helperd libbeegfs-ib beegfs-utils beegfs-common >/dev/null;

    # sudo rm -rf ~/beegfs /disk/be* 2>/dev/null || true
    # mkdir ~/beegfs 2>/dev/null
    # mkdir /dev/shm/beegfs/ 2>/dev/null

    # mount local disk
    # sudo mount /dev/md0 /disk/ 2>/dev/null || true
fi

# install beegfs
if [[ "${role}" == "master" ]]; then
    if [[ ! -d /mnt/ext4ramdisk/beegfs/ ]]; then
        # create RAM disk for metadata
        sudo mkdir /mnt/ramdisk || true
        sudo mount -t ramfs ramfs /mnt/ramdisk
        sudo dd if=/dev/zero of=/mnt/ramdisk/ext4.image bs=1000000 count=51200
        sudo mkfs.ext4 /mnt/ramdisk/ext4.image

        sudo mkdir /mnt/ext4ramdisk || true
        sudo mount -o loop /mnt/ramdisk/ext4.image /mnt/ext4ramdisk
        sudo chown -R $(whoami) /mnt/ext4ramdisk
        sudo mkdir /mnt/ext4ramdisk/beegfs/

        dd if=/dev/random of=/tmp/connauthfile bs=128 count=1 >/dev/null || true;
        # copy to tmp so that other servers can fetch it
        sudo cp /tmp/connauthfile /etc/beegfs/connauthfile;

        sudo /opt/beegfs/sbin/beegfs-setup-mgmtd -p /mnt/ext4ramdisk/beegfs/beegfs_mgmtd
        sudo /opt/beegfs/sbin/beegfs-setup-meta -p /mnt/ext4ramdisk/beegfs/beegfs_meta -m ${MASTER_IP}
        sleep 2
        sudo sed -i "/^connAuthFile/c connAuthFile = /etc/beegfs/connauthfile" /etc/beegfs/beegfs-*.conf;
    fi;

    # start the master server
    sudo systemctl start beegfs-mgmtd
    # start the metadata server
    sudo systemctl start beegfs-meta
elif [[ "${role}" == "chunkserver" ]]; then
    sudo cp /tmp/connauthfile /etc/beegfs/connauthfile;
    sudo chown root:root /etc/beegfs/connauthfile;
    sudo chmod 400 /etc/beegfs/connauthfile;

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p ${CHUNK_SERVER_DISK_PATH}/beegfs_storage -m ${MASTER_IP}

    sudo sed -i "s|/mnt/beegfs|${CLUSTER_FS_MOUNT_DIR}|g" /etc/beegfs/beegfs-mounts.conf;
    sudo /opt/beegfs/sbin/beegfs-setup-client -m ${MASTER_IP}

    sudo sed -i "/^connAuthFile/c connAuthFile = /etc/beegfs/connauthfile" /etc/beegfs/beegfs-*.conf

    # make sure it uses the experiment interface not the control interface
    ifconfig | grep vlan | cut -d : -f 1 | sudo tee /etc/beegfs/interface.conf
    sudo sed -i "/^connInterfacesFile/c connInterfacesFile = /etc/beegfs/interface.conf" /etc/beegfs/beegfs-client.conf
    sudo sed -i "/^connInterfacesFile/c connInterfacesFile = /etc/beegfs/interface.conf" /etc/beegfs/beegfs-storage.conf

    # start the chunkserver
    sudo systemctl start beegfs-storage
    sleep 20
    # start the client
    sudo systemctl start beegfs-helperd
    sudo systemctl start beegfs-client

else
    echo "unknown role: ${role}"
    exit 1
fi

# beegfs-ctl --listnodes --nodetype=meta --nicdetails
# beegfs-ctl --listnodes --nodetype=storage --nicdetails
# beegfs-ctl --listnodes --nodetype=client --nicdetails
# beegfs-net                # Displays connections the client is actually using
# beegfs-check-servers      # Displays possible connectivity of the services
# beegfs-df                 # Displays free space and inodes of storage and metadata targets

