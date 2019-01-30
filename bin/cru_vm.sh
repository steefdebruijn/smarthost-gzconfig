#!/bin/bash
# Create or update a vm.

# Expected: a folder on /opt/gzconfig/share/vmdefs/{$1}
# Files: at least a ${1}.json describing the vm. Will be used to create the vm
# Specials:
#  - Docker:
#    use docker name:tag as image_uuid, will be fetched on vm creation
#    if lofs mounting filesystem(s) from GZ, list them in a file named 'fs'
#    if needing extra environment variables, list them in a file named 'env', no quotes

vmdefs=/opt/gzconfig/share/vmdefs

function zone_exists {
    vmadm lookup -1 alias=$1 2>&1 > /dev/null
}

function latest_smartos_image {
    uuid=$(imgadm avail name=$1 -o uuid | tail -1)
    dump_stdio=$(imgadm import $uuid)
    echo $uuid
}

function latest_docker_image {
    dump_stdio=$(imgadm import $1)
    image=($(echo $1 | tr ':' '\n'))
    imgadm list type=docker docker_repo=${image[0]} docker_tags=${image[1]} -o uuid | tail -1
}

function install_zone {
    if test -f ${vmdefs}/${1}/fs; then
	echo Creating zfs datasets for ${1}...
        cat ${vmdefs}/${1}/fs | while read f; do
	    test -d /${f} || zfs create ${f}
	done
    fi
    if test -f ${vmdefs}/${1}/${1}.json; then
	image=$(cat ${vmdefs}/${1}/${1}.json | json image_uuid)
	if test "$(cat ${vmdefs}/${1}/${1}.json | json docker)" == "true"; then
	    echo Configuring ${1} as docker zone ...
	    uuid=$(latest_docker_image $image)
	    docker_config=$(imgadm get $uuid | sed -e 's|\\t| |g' | json manifest.tags.docker:config)
	    docker_entrypoint=$(echo $docker_config | json Entrypoint)
	    docker_cmd=$(echo $docker_config | json Cmd)
	    docker_wd=$(echo $docker_config | json WorkingDir)
	    docker_env=$(echo $docker_config | json Env)
	    if test -f ${vmdefs}/${1}/env; then
		while read envline; do
                    docker_env=$(echo $docker_env | sed -e "s|]$|, \\\"${envline}\\\" ]|")
		done < <(cat ${vmdefs}/${1}/env)
	    fi
	    docker_entrypoint=$(echo $docker_entrypoint | sed -e 's|"|\\"|g')
	    docker_cmd=$(echo $docker_cmd | sed -e 's|"|\\"|g') # todo: \t not working nulls should be omitted from json
	    docker_env=$(echo $docker_env | sed -e 's|"|\\"|g')
	else
            echo Configuring ${1} as OS zone ...
            uuid=$(latest_smartos_image $image)
	fi
	echo Creating zone ${1}...
	eval "cat <<EOF
$(</${vmdefs}/${1}/${1}.json)
EOF
" | json -e "image_uuid=\"$uuid\""  | vmadm create
    fi
    zone=$(vmadm lookup -1 alias=$1)
    if test -f ${vmdefs}/${1}/packages; then
	echo Installing packages...
	zlogin $zone "pkgin -fy upgrade-all"
	cat ${vmdefs}/${1}/packages | while read p; do
	    echo "  - $p"
	    zlogin $zone "pkgin -y install $p"
	done
    fi
    if test -d ${vmdefs}/${1}/scripts; then
	echo Installing scripts...
	zlogin $(vmadm lookup -1 alias=$1) "mkdir scripts"
	PWD=$(pwd)
	cd ${vmdefs}/${1}
	for script in scripts/*; do
	    cat $script | zlogin $(vmadm lookup -1 alias=$1) "tee $script > /dev/null"
	    zlogin $(vmadm lookup -1 alias=$1) "chmod +x $script"
	done
	cd $PWD
    fi
    if test -f ${vmdefs}/${1}/scripts/setup.sh; then
	echo Running install script...
	zlogin $(vmadm lookup -1 alias=$1) "scripts/setup.sh"
    fi
    # install port forwarding rules and (re)configure reversed proxy and https
    if test -f ${vmdefs}/${1}/ports; then
        echo Configuring ports and reversed proxy on gateway...
	gateway=$(vmadm lookup -1 alias=gateway)
	ip=$(cat ${vmdefs}/${1}/${1}.json | json nics | json -c 'nic_tag=="stub0"'  | json 0 | json ip)
	if test -z "$ip"; then
	    echo ERROR: port forwarding not possible on non-stub NICs
	    exit 1
	fi
	cat ${vmdefs}/${1}/ports | while read host port; do
	    zlogin $gateway "scripts/add-virtual-host.sh $host $ip $port"
	done
    fi
}

if test -z "$1"; then
    echo Please tell me which VM to create/update
    exit 1
fi

zone_exists $1 || install_zone $1
