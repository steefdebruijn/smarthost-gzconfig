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

function latest_docker_image {
    dump_stdio=$(imgadm import $1)
    image=($(echo $1 | tr ':' '\n'))
    imgadm list type=docker docker_repo=${image[0]} docker_tags=${image[1]} -o uuid | tail -1
}

function install_zone {
    if test -f ${vmdefs}/${1}/fs; then
	echo Creating zfs datasets for ${1} ...
        cat ${vmdefs}/${1}/fs | while read f; do
	    test -d /${f} || zfs create ${f}
	done
    fi
    if test -f ${vmdefs}/${1}/${1}.json; then
	image=$(cat ${vmdefs}/${1}/${1}.json | json image_uuid)
	if test "$(cat ${vmdefs}/${1}/${1}.json | json docker)" == "true"; then
	    echo Configuring ${1} as docker zone ...
	    uuid=$(latest_docker_image $image)
	    docker_config=$(imgadm get $uuid | json manifest.tags.docker:config)
	    docker_entrypoint=$(echo $docker_config | json Entrypoint)
	    docker_cmd=$(echo $docker_config | json Cmd)
	    docker_wd=$(echo $docker_config | json WorkingDir)
	    docker_env=$(echo $docker_config | json Env)
	    if test -f ${vmdefs}/${1}/env; then
		while read envline; do
                    docker_env=$(echo $docker_env | sed -e "s|]$|, \\\"${envline}\\\" ]|")
		done < <(cat ${vmdefs}/${1}/env)
	    fi
	    docker_entrypoint=$(echo $docker_entrypoint | sed -e 's|\\t|\\\\t|g' -e 's|"|\\"|g')
	    docker_cmd=$(echo $docker_cmd | sed -e 's|\\t|\\\\t|g' -e 's|"|\\"|g') # todo: \t not working nulls should be omitted from json
	    docker_env=$(echo $docker_env | sed -e 's|\\t|\\\\t|g' -e 's|"|\\"|g')
	else
	    echo OS Zones not supported yet
	    exit 1
	fi
	echo Creating zone ${1} ...
	eval "cat <<EOF
$(</${vmdefs}/${1}/${1}.json)
EOF
" | json -e "image_uuid=\"$uuid\""  | vmadm create
    fi
}

if test -z "$1"; then
    echo Please tell me which VM to create/update
    exit 1
fi

zone_exists $1 || install_zone $1
