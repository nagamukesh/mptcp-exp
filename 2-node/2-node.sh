##############################################
# Topology                                   #
#  _______   10mbit, 5ms     _______        #     
# |       |-----------------|       |        #      
# |  h1   |                 |  h2   |       #
# |_______|-----------------|_______|       #      
#             5mbit, 10ms                   #
##############################################

#!/bin/sh

# Function to automatically configure MPTCP and routing for a namespace
setup_mptcp_endpoints() {
    local ns=$1
    local id=1

    # Flush existing endpoints
    ip -n $ns mptcp endpoint flush

    # Get all interfaces except loopback and their IPs
    for iface in $(ip netns exec $ns ip -4 addr show | grep -v "lo:" | grep "inet" | awk '{print $NF}'); do
        # Get IP address for this interface
        local ip=$(ip netns exec $ns ip -4 addr show dev $iface | grep inet | awk '{print $2}' | cut -d'/' -f1)
        
        if [ ! -z "$ip" ]; then
            echo "Adding MPTCP endpoint for $ns: $ip on $iface with id $id"
            ip -n $ns mptcp endpoint add $ip dev $iface id $id signal subflow
            id=$((id + 1))
        fi
    done
}

# Clean up existing namespaces
ip -all netns delete

# Create network namespaces
ip netns add h1
ip netns add h2

# Disable the reverse path filtering
sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h1 sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h2 sysctl -w net.ipv4.conf.all.rp_filter=0

# Enable MPTCP on both network namespaces
ip netns exec h1 sysctl -w net.mptcp.enabled=1
ip netns exec h2 sysctl -w net.mptcp.enabled=1

# Create two virtual ethernet (veth) pairs between h1 and h2
ip link add eth1a netns h1 type veth peer eth2a netns h2
ip link add eth1b netns h1 type veth peer eth2b netns h2

# Assign IP address to each interface on h1
ip -n h1 address add 10.0.0.1/24 dev eth1a
ip -n h1 address add 192.168.0.1/24 dev eth1b

# Assign IP address to each interface on h2
ip -n h2 address add 10.0.0.2/24 dev eth2a
ip -n h2 address add 192.168.0.2/24 dev eth2b

# Set the data rate and delay on the veth devices at h1
ip netns exec h1 tc qdisc add dev eth1a root netem delay 5ms rate 10mbit
ip netns exec h1 tc qdisc add dev eth1b root netem delay 10ms rate 5mbit

# Set the data rate and delay on the veth devices at h2
ip netns exec h2 tc qdisc add dev eth2a root netem delay 5ms rate 10mbit
ip netns exec h2 tc qdisc add dev eth2b root netem delay 10ms rate 5mbit

# Turn ON all ethernet devices
ip -n h1 link set lo up
ip -n h2 link set lo up
ip -n h1 link set eth1a up
ip -n h1 link set eth1b up
ip -n h2 link set eth2a up
ip -n h2 link set eth2b up

# Enable IP forwarding
ip netns exec h1 sysctl -w net.ipv4.ip_forward=1
ip netns exec h2 sysctl -w net.ipv4.ip_forward=1

# Flush existing MPTCP endpoints
ip -n h1 mptcp endpoint flush
ip -n h2 mptcp endpoint flush

# Automatically setup MPTCP and routing for both namespaces
setup_mptcp_endpoints h1
setup_mptcp_endpoints h2

# Add default routes with multiple paths
ip netns exec h1 ip route add default scope global nexthop via 10.0.0.2 dev eth1a nexthop via 192.168.0.2 dev eth1b
ip netns exec h2 ip route add default scope global nexthop via 10.0.0.1 dev eth2a nexthop via 192.168.0.1 dev eth2b

# Print configuration status
echo "=== MPTCP Configuration Status ==="
echo "H1 endpoints:"
ip netns exec h1 ip mptcp endpoint show
echo -e "\nH2 endpoints:"
ip netns exec h2 ip mptcp endpoint show
echo -e "\nRouting tables:"
echo "H1 rules:"
ip netns exec h1 ip rule show
echo "H2 rules:"
ip netns exec h2 ip rule show