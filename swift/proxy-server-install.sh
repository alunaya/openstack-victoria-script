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

    configArray[port]=8080
    configArray[user]="swift"
    configArray[swift_directory]="/etc/swift"
    configArray[auth_url]="http://localhost:5000"
    configArray[memcached_server]="http://localhost:11211"
    configArray[project_domain_id]="default"
    configArray[user_domain_id]="default"
    configArray[project_name]="service"
    configArray[keystone_user]="swift"
    configArray[keystone_pass]="vts"

    while [ "$doneConfig" -eq 0 ];
    do
        for parameter in  ${!configArray[@]}
        do 
            read -p "Enter value for ${parameter}[${configArray[$parameter]}]: " tmpInput
            if [ -z "${tmpInput}" ]; 
                then
                    echo "value of parameter \"$parameter\" will be set to value \"${configArray[$parameter]}\""
                else
                    configArray[$parameter]=$tmpInput
            fi
            echo ""
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

mkdir -p "${configArray[swift_directory]}"
# update repository
# apt update

# # add deadsnakes repo and install python 3
# apt install -y software-properties-common
# yes "" | add-apt-repository ppa:deadsnakes/ppa
# apt install python3

# # install swift and python dependencies
# yes "" | apt-get install swift swift-proxy python-swiftclient \
#   python-keystoneclient python-keystonemiddleware \
#   memcached


