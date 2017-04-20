#!/usr/bin/env bash
{
if [[ `hostname` = *"ceph"* ]] || [[ `hostname` = *"osd-compute"* ]]; then

    # Verify the passed network interface exists 
    if [[ ! $(ip add show $OSD_NUMA_INTERFACE) ]]; then
	exit 1
    fi

    # If NUMA related packages are missing, then install them
    # If packages are baked into image, no install attempted
    for PKG in numactl hwloc; do 
	if [[ ! $(rpm -q $PKG) ]]; then
	    yum install -y $PKG
	    if [[ ! $? ]]; then
		echo "Unable to install $PKG with yum"
		exit 1
	    fi
	fi
    done

    if [[ ! $(lstopo-no-graphics | tr -d [:punct:] | egrep "NUMANode|$OSD_NUMA_INTERFACE") ]];
    then
	echo "No NUMAnodes found. Exiting."
	exit 1
    fi
    
    # Find the NUMA socket of the $OSD_NUMA_INTERFACE
    declare -A NUMASOCKET
    while read TYPE SOCKET_NUM NIC ; do 
	if [[ "$TYPE" == "NUMANode" ]]; then 
	    NUMASOCKET=$(echo $SOCKET_NUM | sed s/L//g); 
	fi 
	if [[ "$NIC" == "$OSD_NUMA_INTERFACE" ]]; then
	    # because $NIC is the $OSD_NUMA_INTERFACE,
	    # the NUMASOCKET has been set correctly above
	    break # so stop looking 
	fi 
    done < <(lstopo-no-graphics | tr -d [:punct:] | egrep "NUMANode|$OSD_NUMA_INTERFACE")

    if [[ -z $NUMASOCKET ]]; then 
	echo "No NUMAnode found for $OSD_NUMA_INTERFACE. Exiting."
	exit 1
    fi

    UNIT='/usr/lib/systemd/system/ceph-osd@.service'
    # Preserve the original ceph-osd start command
    CMD=$(crudini --get $UNIT Service ExecStart)

    if [[ $(echo $CMD | grep numactl) ]]; then
	echo "numactl already in $UNIT. No changes required."
	exit 0  
    fi

    # NUMA control options to append in front of $CMD
    NUMA="/usr/bin/numactl -N $NUMASOCKET --preferred=$NUMASOCKET"

    # Update the unit file to start with numactl
    # TODO: why doesn't a copy of $UNIT in /etc/systemd/system work with numactl?
    crudini --verbose --set $UNIT Service ExecStart "$NUMA $CMD"

    # Reload so updated file is used
    systemctl daemon-reload

    # Restart OSDs with NUMA policy (print results for log)
    OSD_IDS=$(ls /var/lib/ceph/osd | awk 'BEGIN { FS = "-" } ; { print $2 }')
    for OSD_ID in $OSD_IDS; do
	echo -e "\nStatus of OSD $OSD_ID before unit file update\n"
	systemctl status ceph-osd@$OSD_ID 
	echo -e "\nRestarting OSD $OSD_ID..."
	systemctl restart ceph-osd@$OSD_ID
	echo -e "\nStatus of OSD $OSD_ID after unit file update\n"
	systemctl status ceph-osd@$OSD_ID
    done
fi
}  2>&1 > /root/post_deploy_heat_output.txt
