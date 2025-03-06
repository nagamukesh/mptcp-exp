#!/bin/bash

# filepath: /home/mukesh/mptcp-exp/2-node/collect_info.sh

OUTPUT_FILE="/home/mukesh/mptcp-exp/2-node/mptcp_test_info.txt"

# Function to collect information from a namespace
collect_info() {
    local ns=$1
    local output=$2

    echo "=== Information for namespace: $ns ===" >> $output
    echo "IP Addresses:" >> $output
    ip netns exec $ns ip addr show >> $output
    echo -e "\nRouting Table:" >> $output
    ip netns exec $ns ip route show >> $output
    echo -e "\nMPTCP Endpoints:" >> $output
    ip netns exec $ns ip mptcp endpoint show >> $output
    echo -e "\nIP Rules:" >> $output
    ip netns exec $ns ip rule show >> $output
    echo -e "\nNetwork Interfaces:" >> $output
    ip netns exec $ns ip link show >> $output
    echo -e "\nTraffic Control Settings:" >> $output
    ip netns exec $ns tc qdisc show >> $output
    echo -e "\n" >> $output
}

# Function to collect RTT using ping
collect_rtt() {
    local ns=$1
    local target_ip=$2
    local output=$3

    echo "=== RTT to $target_ip from namespace: $ns ===" >> $output
    ip netns exec $ns ping -c 5 $target_ip >> $output
    echo -e "\n" >> $output
}

# Function to collect iperf3 statistics
collect_iperf3_stats() {
    local ns_client=$1
    local ns_server=$2
    local server_ip=$3
    local output=$4

    echo "=== iperf3 Test from $ns_client to $ns_server ($server_ip) ===" >> $output
    ip netns exec $ns_server iperf3 -s -D
    sleep 1
    ip netns exec $ns_client iperf3 -c $server_ip -t 10 >> $output
    ip netns exec $ns_server pkill iperf3
    echo -e "\n" >> $output
}

# Create or clear the output file
> $OUTPUT_FILE

# Collect information from both namespaces
collect_info h1 $OUTPUT_FILE
collect_info h2 $OUTPUT_FILE

# Collect RTT information
collect_rtt h1 10.0.0.2 $OUTPUT_FILE
collect_rtt h1 192.168.0.2 $OUTPUT_FILE
collect_rtt h2 10.0.0.1 $OUTPUT_FILE
collect_rtt h2 192.168.0.1 $OUTPUT_FILE

# Collect iperf3 statistics
collect_iperf3_stats h1 h2 10.0.0.2 $OUTPUT_FILE
collect_iperf3_stats h1 h2 192.168.0.2 $OUTPUT_FILE

# Print a message indicating where the information has been saved
echo "MPTCP test info and stats has been collected and saved to $OUTPUT_FILE"