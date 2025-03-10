################################################################################
#                                                                              #
#                               Network Topology                               #
#      ____                 ____                 ____                ____      #
#     |    |               |    |               |    |  5mbit,10ms  |    |     #
#     |    |  15mbit,10ms  |    |  10mbit,10ms  |    | ------------ |    |     #
#     | h1 | ------------- | r1 | ------------- | r2 |              | h2 |     #
#     |    |               |    |               |    | ------------ |    |     #
#     |____|               |____|               |____|  5mbit,10ms  |____|     #
#                                                                              #
################################################################################


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
ip netns add r1
ip netns add r2

# Disable the reverse path filtering
sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h1 sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h2 sysctl -w net.ipv4.conf.all.rp_filter=0

# Enable MPTCP on all the network namespaces
ip netns exec h1 sysctl -w net.mptcp.enabled=1
ip netns exec h2 sysctl -w net.mptcp.enabled=1

ip netns exec r1 sysctl -w net.mptcp.enabled=1
ip netns exec r2 sysctl -w net.mptcp.enabled=1

# Create virtual ethernet (veth) pairs
ip link add eth1a netns h1 type veth peer eth2a netns r1
ip link add eth2b netns r1 type veth peer eth3a netns r2
ip link add eth3b netns r2 type veth peer eth4b netns h2
ip link add eth3c netns r2 type veth peer eth4c netns h2

# Assign IP address to each interface on h1
ip -n h1 address add 10.0.0.1/24 dev eth1a

# Assign IP address to each interface on r1
ip -n r1 address add 10.0.0.2/24 dev eth2a
ip -n r1 address add 10.0.1.1/24 dev eth2b

# Assign IP address to each interface on r2
ip -n r2 address add 10.0.1.2/24 dev eth3a
ip -n r2 address add 10.0.2.1/24 dev eth3b
ip -n r2 address add 10.0.3.1/24 dev eth3c

# Assign IP address to each interface on h2
ip -n h2 address add 10.0.2.2/24 dev eth4b
ip -n h2 address add 10.0.3.2/24 dev eth4c

# Set the data rate and delay on the veth devices at h1
ip netns exec h1 tc qdisc add dev eth1a root netem delay 10ms rate 15mbit

# Set the data rate and delay on the veth devices at r1
ip netns exec r1 tc qdisc add dev eth2a root netem delay 10ms rate 15mbit
ip netns exec r1 tc qdisc add dev eth2b root netem delay 10ms rate 10mbit

# Set the data rate and delay on the veth devices at r2
ip netns exec r2 tc qdisc add dev eth3a root netem delay 10ms rate 10mbit
ip netns exec r2 tc qdisc add dev eth3b root netem delay 10ms rate 8mbit
ip netns exec r2 tc qdisc add dev eth3c root netem delay 10ms rate 5mbit

# Set the data rate and delay on the veth devices at h2
ip netns exec h2 tc qdisc add dev eth4b root netem delay 10ms rate 8mbit
ip netns exec h2 tc qdisc add dev eth4c root netem delay 10ms rate 5mbit

# Turn ON all ethernet devices
ip -n h1 link set lo up
ip -n r1 link set lo up
ip -n r2 link set lo up
ip -n h2 link set lo up
ip -n h1 link set eth1a up
ip -n r1 link set eth2a up
ip -n r1 link set eth2b up
ip -n r2 link set eth3a up
ip -n r2 link set eth3b up
ip -n r2 link set eth3c up
ip -n h2 link set eth4b up
ip -n h2 link set eth4c up

# Enable IP forwarding
ip netns exec h1 sysctl -w net.ipv4.ip_forward=1
ip netns exec h2 sysctl -w net.ipv4.ip_forward=1
ip netns exec r1 sysctl -w net.ipv4.ip_forward=1
ip netns exec r2 sysctl -w net.ipv4.ip_forward=1

# Flush existing MPTCP endpoints
ip -n h1 mptcp endpoint flush
ip -n h2 mptcp endpoint flush
ip -n r1 mptcp endpoint flush
ip -n r2 mptcp endpoint flush


# Automatically setup MPTCP and routing
setup_mptcp_endpoints r2
setup_mptcp_endpoints h2

# Add default routes for H1
ip netns exec h1 ip route add default via 10.0.0.2 dev eth1a

# Add default routes for R1
ip netns exec r1 ip route add default via 10.0.1.2 dev eth2b

# Add default routes for R2 (one path with R1 and multiple paths to H2)
ip netns exec r2 ip route add default via 10.0.1.1 dev eth3a
ip netns exec r2 ip route add default scope global nexthop via 10.0.2.2 dev eth3b
ip netns exec r2 ip route add default scope global nexthop via 10.0.3.2 dev eth3c

# Add multiple paths in both directions (R2 <-> H2)
ip netns exec h2 ip route add default scope global nexthop via 10.0.2.1 dev eth4b
ip netns exec h2 ip route add default scope global nexthop via 10.0.3.1 dev eth4c


echo "=== MPTCP Configuration Status ==="
echo "R2 endpoints:"
ip netns exec r2 ip mptcp endpoint show
echo -e "\nH2 endpoints:"
ip netns exec h2 ip mptcp endpoint show
echo -e "\nRouting tables:"
echo "H1 rules:"
ip netns exec h1 ip rule show
echo "H2 rules:"
ip netns exec h2 ip rule show























