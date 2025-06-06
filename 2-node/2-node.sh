############################################## 
# Topology                                   #
#  _______   10mbit, 5ms     _______         #     
# |       |-----------------|       |        #      
# |  h1   |                 |  h2   |        #
# |_______|-----------------|_______|        #      
#             5mbit, 10ms                    #
##############################################

#!/bin/sh

# Clean up previous namespaces
ip -all netns delete

# Create network namespaces
ip netns add h1
ip netns add h2

# Disable the reverse path filtering
sysctl -w net.ipv4.conf.all.rp_filter=0

# Enable MPTCP on both network namespaces
ip netns exec h1 sysctl -w net.mptcp.enabled=1
ip netns exec h2 sysctl -w net.mptcp.enabled=1

# Create two virtual ethernet (veth) pairs between h1 and h2
ip link add eth1a netns h1 type veth peer eth2a netns h2
ip link add eth1b netns h1 type veth peer eth2b netns h2

# Assign IP addresses to each interface on h1
ip -n h1 address add 10.0.0.1/24 dev eth1a
ip -n h1 address add 192.168.0.1/24 dev eth1b

# Assign IP addresses to each interface on h2
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

# Flush existing MPTCP endpoints
ip -n h1 mptcp endpoint flush
ip -n h2 mptcp endpoint flush

# Enable IP forwarding
ip netns exec h2 sysctl -w net.ipv4.ip_forward=1

# Create two routing tables for two interfaces in h1
ip netns exec h1 ip rule add from 10.0.0.1 table 1
ip netns exec h1 ip rule add from 192.168.0.1 table 2

# Configure the two routing tables
ip netns exec h1 ip route add default via 10.0.0.2 dev eth1a table 1
ip netns exec h1 ip route add 10.0.0.0/24 dev eth1a scope link table 1

ip netns exec h1 ip route add default via 192.168.0.2 dev eth1b table 2
ip netns exec h1 ip route add 192.168.0.0/24 dev eth1b scope link table 2

# Set MPTCP limits to allow multiple subflows and address advertisements
ip netns exec h1 ip mptcp limits set subflow 2 add_addr_accepted 2
ip netns exec h2 ip mptcp limits set subflow 2 add_addr_accepted 2

# Add MPTCP endpoints with subflow and fullmesh flags on h1
ip netns exec h1 ip mptcp endpoint add 10.0.0.1 dev eth1a subflow fullmesh
ip netns exec h1 ip mptcp endpoint add 192.168.0.1 dev eth1b subflow fullmesh

# Add MPTCP endpoints with signal flag on h2
ip netns exec h2 ip mptcp endpoint add 10.0.0.2 dev eth2a signal
ip netns exec h2 ip mptcp endpoint add 192.168.0.2 dev eth2b signal
