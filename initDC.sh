#!/bin/bash
#
# ============================
# Author: Cedric Bhihe
# Email: cedric.bhihe@gmail.com
# Creation Date: 2017.05.30
# ============================

#                   initDC
#
# Script runs N serf agent(s) in so many Docker containers, creates
# cluster of serf nodes.
# Script executed from within the instance (host)  environment.
# Script called with exactly 2 arguments: 
#	- the Docker Hub container image name
#	- N, nbr of DCs to create 
# `/bin/bash' v4.0+ necessary for array support

# Update instance package environment
# sudo apt-get -q update; sudo apt-get -y upgrade
# sudo apt-get install -y bridge-utils iputils-ping

# Discover each container's ID, private and public IP and VETH 
# Write them in $contDB txt file

datestamp="$(/bin/date +%Y%m%d-%H%M%S)"
# instance private IP
inst_privip="$(ifconfig eth0 | awk '/inet addr/ {print substr($2,6)}')"
# instance public IP
inst_pubip="$(wget -qO- http://instance-data/latest/meta-data/public-ipv4)"
# Docker containers and DC internal process-id database 
contDB="setup.db"

# log file for container creation and serf agent configuration
/bin/cat <<EOF > setup.log
Log date: "$datestamp"
====================================
EOF

printf "Date: %s\nAWS EC2 instance host name: %s\n" "$datestamp" \
    "$(dig -x "$(curl -s checkip.amazonaws.com)" +short)" > "$contDB"
printf "Private instance IP: %s\nPublic instance IP: %s\n\n" \
    "$inst_privip" "$inst_pubip" >> "$contDB"
printf "DC-# DC-id     DC-privIP    DC-veth    Node-id\n" >> "$contDB"

declare -a serfID;  # declare array of serf/etcd agents' IDs
declare -a contID;  # declare array of DCs' IDs

# Nbr of DCs to be instantiated from image
dockerImage="$1"
maxDC="$2"

for j in $(seq 1 "$maxDC"); do

	# build node identification string 
	node_id="$(printf "%s_%03d" "$inst_pubip" "$j")"

	# create containers, launch agents in each container and join them

	case "$j" in
		1)
			serf_id="$(docker run -d --name serfDC"${j}" --rm \
				-p 7946 -p 7373 -p 8443 \
				"$dockerImage" agent -node="$node_id" -iface=eth0 )"
			cont_id="$(docker ps -l -q)"
			# discover container private IP
			cont_privip="$(docker inspect -f \
				'{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' \
				"$cont_id")"
			joinIP="$cont_privip"
			;;
		*)	
			serf_id="$(docker run -d --name serfDC"${j}" --rm \
			 	-p 7946 -p 7373 -p 8443 \
			 	"$dockerImage" agent -node="$node_id" -iface=eth0)"
			cont_id="$(docker ps -l -q)"
			# [ "$DEBUG" == 'true' ] && set -x
			docker exec "$cont_id" bash -c 'serf join '"$joinIP" 
			# [ "$DEBUG" == 'false' ] && set +x
			# discover container private IP
			cont_privip="$(docker inspect -f \
				'{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' \
				"$cont_id")"
			;;
	esac

	# update container packages, store launch log 
    serfID=("${serfID[@]}" "$serf_id")
    contID=("${contID[@]}" "$cont_id")
    printf "\nContainer ID: %s\n" "$cont_id" >> setup.log

    # update of packages inside DC and install ethtool
    docker exec "$cont_id" apk --update add --no-cache ethtool >> setup.log

	# discover metadata
	grep_str="$(docker exec "$cont_id" ethtool -S eth0 | \
	    awk '/peer_ifindex/ {print $2}')"": veth"
    cont_veth="$(sudo ip link | grep "$grep_str"|awk '{print substr($2,1,11)}')"

	# clean up superfluous package
    docker exec "$cont_id" apk del ethtool >> setup.log
    docker exec "$cont_id" rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
		>> setup.log

	# create database
    printf "%d %s %s %s %s\n" \
        "$j" "$cont_id" "$cont_privip" "$cont_veth" "$serf_id" | tee -a "$contDB"

done

printf "%d containers created.\n" "${#serfID[@]}"
docker ps
docker exec "$cont_id" serf members

# exit 0
