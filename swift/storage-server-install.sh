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

    configArray[management_ip_address]=""
    configArray[number_of_partition]=3
    configArray[size_of_partition]="10GB"
    configArray[loopback_device_location]="/srv/swift"
    configArray[loopback_mount_folder]="/srv/node"

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
# apt-get -y install xfsprogs rsync
# apt-get -y install swift swift-account swift-container swift-object

# mkdir -p ${configArray[loopback_device_location]}
# mkdir -p ${configArray[loopback_mount_folder]}

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

# rm "${configArray[loopback_device_location]}/$*"

for (( i=1;i<=${configArray[number_of_partition]};i++)); do
    truncate -s "${configArray[size_of_partition]}" "${configArray[loopback_device_location]}/swift-partition-$i.dsk"
    mkfs.xfs "${configArray[loopback_device_location]}/swift-partion-$i"
    mkdir -p "${configArray[loopback_mount_folder]}/sdb$i"
    
done