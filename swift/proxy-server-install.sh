#!/bin/bash

clear
if [ "$EUID" -ne 0 ]
    then echo "Please run as root user or use sudo"
    exit
fi

# Get config parameter
while true
do
    while true
        do
        read -p "Enter listening port for proxy[8080]:" port

        if [ -z $port ]; then
            echo "port value will be default value \"8080\""
            port=8080
            break
        fi

        if [ $port -lt 1 -o $port -gt 65535 ]; then
            echo "Invalid port"
            else
            break
        fi
    done

    read -p "Enter proxy user[swift]:" user
    if [ -z "$user" ]; then
        echo "user value will be default value \"swift\""
    fi


    while true
    do
        read -p "Enter swift directory[/etc/swift]:" configDir

        if [ -z $configDir ] then
            mkdir -p /etc/swift
            configDir="/etc/swift"
            echo "swift directory value will be default value \"/etc/swift\""
            break
        fi

        if [ ! -d "$configDir" ]; then
            echo "This path doesn't exist or doesn't point to a directory"
            else
            break
        fi
    done

    echo "This server will have these following configuration:"
    echo "Litening port: ${port}"
    echo "Proxy User: ${user}"
    echo "Swift directory: $configDir"
    read -p "Are you sure you want to keep these configuration[Y/N]"
    while true
    do
        case $REPLY in
            "Y")
                break
                ;;
            "N")
                break
                ;;
            "*")
                echo "Invalid input"
                ;;
        esac
    done
done

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


