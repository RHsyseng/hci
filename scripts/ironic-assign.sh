# Filename:                ironic-assign.sh
# Description:             Assign ironic nodes to $name
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2016-11-23 19:34:25 jfulton> 
# -------------------------------------------------------
if [[ $# -eq 0 ]] ; then
    echo "usage: $0 <REGEX> <NAME>"
    echo "  <REGEX>   regex matching the nodes to be tagged; e.g. \"730\" or \"630\""
    echo "  <NAME>    name desired for node; e.g. \"osd-compute\" or \"controller\""
    exit 1
fi
regex=$1
name=$2

source ~/stackrc
echo "Assigning nodes from ironic's list that match $regex"
for id in $(ironic node-list | grep available | awk '{print $2}'); do
    match=0;
    match=$(ironic node-show $id | egrep $regex | wc -l);
    if [[ $match -gt 0 ]]; then
	echo $id;
    fi
done > /tmp/n_nodes

count=$(cat /tmp/n_nodes | wc -l)
echo "$count nodes match $regex"

i=0
for id in $(cat /tmp/n_nodes); do
    node="$name-$i"
    ironic node-update $id replace properties/capabilities=node:$node,boot_option:local
    i=$(expr $i + 1)
done

echo "Ironic node properties have been set to the following:"
for ironic_id in $(ironic node-list | awk {'print $2'} | grep -v UUID | egrep -v '^$');
do
    echo $ironic_id;
    ironic node-show $ironic_id  | egrep -A 1 "memory_mb|profile|wwn" ;
    echo "";
done
