#!/bin/bash

clear
if [ "$EUID" -ne 0 ]
    then echo "Please run as root user or use sudo"
    exit
fi

# Get config parameter
declare -A configArray

getConfig(){
    declare tmpInput
    declare doneConfig=0

    configArray[management_ip_address]="0.0.0.0"
    configArray[account_service_port]=6202
    configArray[account_recon_cache_path]="/var/cache/swift"
    configArray[container_service_port]=6201
    configArray[container_recon_cache_path]="/var/cache/swift"
    configArray[object_service_port]=6200
    configArray[object_recon_cache_path]="/var/cache/swift"
    configArray[keystone_user]="swift"
    configArray[mount_folder]="/srv/node"
    # configArray[number_of_partition]=3
    # configArray[size_of_partition]="10GB"
    # configArray[loopback_device_location]="/srv/swift"

    while [ "$doneConfig" -eq 0 ];
    do
        for parameter in  ${!configArray[@]}
        do 
            read -p "Enter value for ${parameter} [${configArray[$parameter]}]: " tmpInput
            if [ -z "${tmpInput}" ]; 
                then
                    echo "value of parameter \"$parameter\" will be set to value \"${configArray[$parameter]}\""
                else
                    configArray[$parameter]=$tmpInput
            fi
        done

        echo ""
        echo "Following config parameters will be use in deploying proxy server"
        for parameter in ${!configArray[@]}
        do
            echo "${parameter}: ${configArray[$parameter]}"
        done
        echo ""

        while true
        do
            read -p "Do you want to proceed[Y/N]:"
            case ${REPLY} in
                Y)
                    doneConfig=1
                    break
                    ;;
                N)
                    break
                    ;;
                *)
                    echo "Invalid Input"
                    ;;         
            esac
        done
    done
}

getConfig

#apt install rsync
apt-get -y install xfsprogs rsync
apt-get -y install swift swift-account swift-container swift-object

mkdir -p ${configArray[mount_folder]}

# mkdir -p ${configArray[loopback_device_location]}
# while true
# do
#     read -p "this script will delete all file in ${configArray[loopback_device_location]}, do you want to proceed [Y/N]:"
#     case ${REPLY} in
#         Y)
#             doneConfig=1
#             break
#             ;;
#         N)
#             break
#             ;;
#         *)
#             echo "Invalid Input"
#             ;;         
#     esac
# done

# # tạo loopback partition
# rm "${configArray[loopback_device_location]}/$*"
# for (( i=1;i<=${configArray[number_of_partition]};i++)); do
#     truncate -s "${configArray[size_of_partition]}" "${configArray[loopback_device_location]}/swift-partition-$i.dsk"
#     mkfs.xfs "${configArray[loopback_device_location]}/swift-partion-$i"
#     mkdir -p "${configArray[mount_folder]}/sdb$i"
#     mount -t xfs "${configArray[loopback_device_location]}/swift-partion-$i" "${configArray[mount_folder]}/sdb$i"
# done

touch /etc/rsyncd.conf
cat <<EOF > /etc/rsyncd.conf
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = ${configArray[management_ip_address]}

[account]
max connections = 2
path = ${configArray[mount_folder]}
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = ${configArray[mount_folder]}
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = ${configArray[mount_folder]}
read only = False
lock file = /var/lock/object.lock
EOF


# thay thế RSYNC_ENABLE=false với RSYNC_ENABLE=true trong file /etc/default/rsync
sudo sed -i '/RSYNC_ENABLE=false/c RSYNC_ENABLE=true' /etc/default/rsync
service rsync start

mkdir -p /etc/swift
touch /etc/swift/account-server.conf
touch /etc/swift/container-server.conf
touch /etc/swift/object-server.conf

cat <<EOF > /etc/swift/account-server.conf
[DEFAULT]
bind_ip = ${configArray[management_ip_address]}
bind_port = ${configArray[account_service_port]}
user = ${configArray[keystone_user]}
swift_dir = /etc/swift
devices = ${configArray[mount_folder]}
mount_check = true
[pipeline:main]
pipeline = healthcheck recon account-server
[app:account-server]
use = egg:swift#account
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = ${configArray[account_recon_cache_path]}
[account-replicator]
[account-auditor]
[account-reaper]
[filter:xprofile]
use = egg:swift#xprofile
EOF

cat <<EOF > /etc/swift/container-server.conf
[DEFAULT]
bind_ip = ${configArray[management_ip_address]}
bind_port = ${configArray[container_service_port]}
user = ${configArray[keystone_user]}
swift_dir = /etc/swift
devices = ${configArray[mount_folder]}
mount_check = true
[pipeline:main]
pipeline = healthcheck recon container-server
[app:container-server]
use = egg:swift#container
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = ${configArray[container_recon_cache_path]}
#recon_cache_path = /var/cache/swift
[container-replicator]
[container-updater]
[container-auditor]
[container-sync]
[filter:xprofile]
use = egg:swift#xprofile
[container-sharder]
EOF

cat <<EOF > /etc/swift/object-server.conf
[DEFAULT]
bind_ip = ${configArray[management_ip_address]}
bind_port = ${configArray[object_service_port]}
user = ${configArray[keystone_user]}
swift_dir = /etc/swift
devices = ${configArray[mount_folder]}
mount_check = true
[pipeline:main]
pipeline = healthcheck recon container-server
[app:container-server]
use = egg:swift#container
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = ${configArray[object_recon_cache_path]}
#recon_cache_path = /var/cache/swift
[container-replicator]
[container-updater]
[container-auditor]
[container-sync]
[filter:xprofile]
use = egg:swift#xprofile
[container-sharder]
EOF

# swift-init all start