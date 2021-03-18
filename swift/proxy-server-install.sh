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
    configArray[memcached_server]="localhost:11211"
    configArray[project_domain_id]="default"
    configArray[user_domain_id]="default"
    configArray[project_name]="service"
    configArray[keystone_user]="swift"
    configArray[keystone_pass]="vts"
    configArray[swift_hash_path_prefix]="WWyi8SeTW7gnJusiRtLn"
    configArray[swift_hash_path_suffix]="RK6Qbe4e4RVmPOu2NrZw"


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

# update repository
apt update

# add deadsnakes repo and install python 3
apt install -y software-properties-common
yes "" | add-apt-repository ppa:deadsnakes/ppa
apt install python3

# install swift and python dependencies
yes "" | apt-get install swift swift-proxy python3-swiftclient \
  python3-keystoneclient python3-keystonemiddleware \
  memcached

configDir=${configArray[swift_directory]}
proxyConfigPath="${configArray[swift_directory]}/proxy-server.conf"
swiftConfigPath="${configArray[swift_directory]}/swift.conf"

mkdir -p "$configDir"

rm -f "$proxyConfigPath"
touch "$proxyConfigPath"
rm -f "$swiftConfigPath"
touch "$swiftConfigPath"

cat <<EOF >> $proxyConfigPath
[DEFAULT]
bind_port = ${configArray[port]}
user = ${configArray[user]}
swift_dir = ${configArray[swift_directory]}
name = swift
log_facility = LOG_LOCAL0
log_level = DEBUG
log_headers = false
log_address = /dev/log
log_max_line_length = 0
[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server
[app:proxy-server]
use = egg:swift#proxy
account_autocreate = true
[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_admin_auditor = admin_ro .reseller_reader
user_test_tester = testing .admin
user_test_tester2 = testing2 .admin
user_test_tester3 = testing3
user_test2_tester2 = testing2 .admin
user_test5_tester5 = testing5 service
[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
www_authenticate_uri = ${configArray[auth_url]}
auth_url = ${configArray[auth_url]}
memcached_servers = ${configArray[memcached_server]}
auth_type = password
project_domain_id = ${configArray[project_domain_id]}
user_domain_id = ${configArray[user_domain_id]}
project_name = ${configArray[project_name]}
username = ${configArray[keystone_user]}
password = ${configArray[keystone_pass]}
delay_auth_decision = true
[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin,user
[filter:s3api]
use = egg:swift#s3api
[filter:s3token]
use = egg:swift#s3token
reseller_prefix = AUTH_
delay_auth_decision = False
auth_uri = http://keystonehost:5000/v3
http_timeout = 10.0
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:cache]
use = egg:swift#memcache
memcache_servers = localhost:11211
[filter:ratelimit]
use = egg:swift#ratelimit
[filter:read_only]
use = egg:swift#read_only
[filter:domain_remap]
use = egg:swift#domain_remap
[filter:catch_errors]
use = egg:swift#catch_errors
[filter:cname_lookup]
use = egg:swift#cname_lookup
[filter:staticweb]
use = egg:swift#staticweb
[filter:tempurl]
use = egg:swift#tempurl
[filter:formpost]
use = egg:swift#formpost
[filter:name_check]
use = egg:swift#name_check
[filter:etag-quoter]
use = egg:swift#etag_quoter
[filter:list-endpoints]
use = egg:swift#list_endpoints
[filter:proxy-logging]
use = egg:swift#proxy_logging
[filter:bulk]
use = egg:swift#bulk
[filter:slo]
use = egg:swift#slo
[filter:dlo]
use = egg:swift#dlo
[filter:container-quotas]
use = egg:swift#container_quotas
[filter:account-quotas]
use = egg:swift#account_quotas
[filter:gatekeeper]
use = egg:swift#gatekeeper
[filter:container_sync]
use = egg:swift#container_sync
[filter:xprofile]
use = egg:swift#xprofile
[filter:versioned_writes]
use = egg:swift#versioned_writes
[filter:copy]
use = egg:swift#copy
[filter:keymaster]
use = egg:swift#keymaster
meta_version_to_write = 2
encryption_root_secret = changeme
[filter:kms_keymaster]
use = egg:swift#kms_keymaster
[filter:kmip_keymaster]
use = egg:swift#kmip_keymaster
[filter:encryption]
use = egg:swift#encryption
[filter:listing_formats]
use = egg:swift#listing_formats
[filter:symlink]
use = egg:swift#symlink
EOF

cat <<EOF >> $swiftConfigPath
[swift-hash]
swift_hash_path_suffix = ${configArray[swift_hash_path_suffix]}
swift_hash_path_prefix = ${configArray[swift_hash_path_prefix]}
[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange
[swift-constraints]
EOF

chown -R root:swift "$configDir"
service memcached restart
service swift-proxy restart

# swift-init all start

exit