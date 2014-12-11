#!/bin/bash -x

echo "Networking an endpoint with container ID $1 and address $2"
CID=$1
IPADDR=$2
GROUP=$3

if [ -z "$CID" ]; then
    echo "No CID"
    exit
fi

if [ -z "$IPADDR" ]; then
    echo "No IP addr"
    exit
fi

if [ -z "$GROUP" ]; then
    echo "No group"
    exit
fi

set -e

NAME=`echo $IPADDR | tr '.' '_'`

CPID=`docker inspect -f '{{.State.Pid}}' $CID`

IFACE=tap${CID:0:11}
echo "CID   = $CID"
echo "CPID  = $CPID"
echo "GROUP = $GROUP"
echo "IFACE = $IFACE"

# Provision the networking
mkdir -p /var/run/netns
ln -s /proc/$CPID/ns/net /var/run/netns/$CPID

# Create the veth pair and move one end into container as eth0 :
ip link add $IFACE type veth peer name tmpiface
ip link set $IFACE up
ip link set tmpiface netns $CPID
ip netns exec $CPID ip link set dev tmpiface name eth0
ip netns exec $CPID ip link set eth0 up

# Add an IP address to that thing :
ip netns exec $CPID ip addr add $IPADDR/32 dev eth0
ip netns exec $CPID ip route add default dev eth0

# Get the MAC address.
MAC=`ip netns exec $CPID ip link show eth0 | grep ether | awk '{print $2}'`

FILE=/opt/plugin/data/${NAME}.txt
cat <<EOF > $FILE
[endpoint $NAME]
id=$CID
ip=$IPADDR
mac=$MAC
host=$HOSTNAME
group=$GROUP

EOF

cat /opt/plugin/data/* > /opt/plugin/data.txt
