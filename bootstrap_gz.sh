#!/usr/bin/bash

function hostinfo {
    echo Bootstrapping Global Zone configuration ...
    echo Host is $(hostname)
    export networkdevice=$(dladm show-phys -o device -p)
    echo IP address is $(ipadm show-addr ${networkdevice}/ -o addr |tail -1|sed -e 's|/24||')
    export defaultgw=$(netstat -rn -f flags:+G -f af:inet | tail -1 | awk '{print $2;}')
    echo Default gateway is $defaultgw
}

function fetchbaseimage {
    echo Fetching base image ...
    imgadm update
    ltsimage=$(imgadm avail name=minimal-64-lts -o uuid | tail -1)
    echo Using minimal LTS image $ltsimage
    imgadm import $ltsimage
}

function create_gzconfig_zone {
    echo Creating Global Zone config zone ...
    test -d /opt/gzconfig || mkdir /opt/gzconfig
    cat << __eof > /opt/gzconfig.vm.json
{
  "alias": "gzconfig",
  "hostname": "gzconfig",
  "brand": "joyent",
  "quota": 10,
  "max_physical_memory": 64,
  "dataset_uuid": "$ltsimage",
  "default_gateway": "$defaultgw",
  "resolvers": [
    "8.8.8.8",
    "8.8.4.4"
  ],
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "dhcp"
    }
  ],
  "filesystems": [
    {
	  "type": "lofs",
	  "source": "/opt/gzconfig",
	  "target": "/opt/gzconfig"
	}
  ]
}
__eof
    vmadm create -f /opt/gzconfig.vm.json
    gzconfig=$(vmadm lookup -1 alias=gzconfig)
    zlogin $gzconfig 'pkgin update && pkgin -y upgrade-all && pkgin -y install git-base'
    zlogin $gzconfig 'cd /opt/gzconfig && git clone https://github.com/steefdebruijn/smarthost-gzconfig .'
}

hostinfo
fetchbaseimage
test $(vmadm lookup -1 alias=gzconfig) || create_gzconfig_zone

exit 0
