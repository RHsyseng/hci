#!/bin/bash

source ~/stackrc
env | grep OS_
SSH_CMD="ssh -l heat-admin"

function usage {
	echo "USAGE: $0 [enable|test]"
	exit 1
}

function enable_stonith {
	# for all controller nodes
	for i in $(nova list | awk ' /controller/ { print $12 } ' | cut -f2 -d=)
	do 
		echo $i
		# create the fence device
		$SSH_CMD $i 'sudo pcs stonith create $(hostname -s)-ipmi fence_ipmilan pcmk_host_list=$(hostname -s) ipaddr=$(sudo ipmitool lan print 1 | awk " /IP Address  / { print \$4 } ") login=root passwd=PASSWORD lanplus=1 cipher=1 op monitor interval=60sr'
		# avoid fencing yourself
		$SSH_CMD $i 'sudo pcs constraint location $(hostname -s)-ipmi avoids $(hostname -s)'
	done

	# enable STONITH devices from any controller
	$SSH_CMD $i 'sudo pcs property set stonith-enabled=true'
	$SSH_CMD $i 'sudo pcs property show'

}

function test_fence {

	for i in $(nova list | awk ' /controller/ { print $12 } ' | cut -f2 -d= | head -n 1)
	do 
		# get REDIS_IP
		REDIS_IP=$($SSH_CMD $i 'sudo grep -ri redis_vip /etc/puppet/hieradata/' | awk '/vip_data.yaml/ { print $2 } ')
	done
	# for all controller nodes
	for i in $(nova list | awk ' /controller/ { print $12 } ' | cut -f2 -d=)
	do 
        	if $SSH_CMD $i "sudo ip a" | grep -q $REDIS_IP
        	then 
			FENCE_DEVICE=$($SSH_CMD $i 'sudo pcs stonith show $(hostname -s)-ipmi' | awk ' /Attributes/ { print $2 } ' | cut -f2 -d=)
			IUUID=$(nova list | awk " /$i/ { print \$2 } ")
			UUID=$(ironic node-list | awk " /$IUUID/ { print \$2 } ")
		else
			FENCER=$i
		fi
	done 2>/dev/null

	echo "REDIS_IP $REDIS_IP"
	echo "FENCER $FENCER"
	echo "FENCE_DEVICE $FENCE_DEVICE"
	echo "UUID $UUID"
	echo "IUUID $IUUID"

	# stonith REDIS_IP owner
	$SSH_CMD $FENCER sudo pcs stonith fence $FENCE_DEVICE

	sleep 30
	
	# fence REDIS_IP owner to keep ironic from powering it on
	sudo ironic node-set-power-state $UUID off
	
	sleep 60
	
	# check REDIS_IP failover
	$SSH_CMD $FENCER sudo pcs status | grep $REDIS_IP
}

if [ "$1" == "test" ]
then
	test_fence
elif [ "$1" == "enable" ]
then
	enable_stonith
else
	usage
fi
