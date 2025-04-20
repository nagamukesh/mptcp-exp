p -all netns delete
killall hostapd wpa_supplicant 2>/dev/null
rmmod mac80211_hwsim 2>/dev/null
sleep 2

# Load wireless simulation module
modprobe mac80211_hwsim radios=2
sleep 2

# Function to check wireless PHY devices
check_phy() {
    for i in $(seq 1 10); do
        if iw phy | grep -q "phy${1}"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Function to check if wireless interface exists
check_wireless() {
    local ns=$1
    local radio=$2
    for i in $(seq 1 10); do
        if ip netns exec ${ns} ip link show wlan${radio} >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Function to setup wireless interface
setup_wireless() {
    local ns=$1
    local radio=$2
    local ssid=$3
    local freq=$4
    local ip=$5

    echo "Setting up wireless interface in ${ns} using phy${radio}..."
    iw phy phy${radio} set netns name ${ns}
    sleep 2

    # Configure wireless interface
    ip netns exec ${ns} ip link set wlan${radio} up
    sleep 1

    if [ "$ns" = "h1" ]; then
        # Setup AP configuration
        cat > /tmp/hostapd_${ns}.conf <<EOF
interface=wlan${radio}
driver=nl80211
ssid=${ssid}
hw_mode=g
channel=1
auth_algs=1
wmm_enabled=1
EOF
        # Start AP
        ip netns exec ${ns} hostapd -B /tmp/hostapd_${ns}.conf
    else
        # Setup client configuration
        cat > /tmp/wpa_supplicant_${ns}.conf <<EOF
network={
    ssid="${ssid}"
    key_mgmt=NONE
}
EOF
        # Start client
        ip netns exec ${ns} wpa_supplicant -B -i wlan${radio} -c /tmp/wpa_supplicant_${ns}.conf
    fi
    sleep 2

    # Assign IP address
    ip netns exec ${ns} ip addr add ${ip}/24 dev wlan${radio}
    sleep 1
}

# Create network namespaces
ip netns add h1
ip netns add h2

# Verify PHY devices
echo "Checking wireless PHY devices..."
if ! check_phy 0 || ! check_phy 1; then
    echo "Wireless PHY devices not properly created"
    exit 1
fi

# Setup system configurations
sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h1 sysctl -w net.ipv4.conf.all.rp_filter=0
ip netns exec h2 sysctl -w net.ipv4.conf.all.rp_filter=0

# Enable MPTCP
ip netns exec h1 sysctl -w net.mptcp.enabled=1
ip netns exec h2 sysctl -w net.mptcp.enabled=1

# Create wired connection
ip link add eth1a netns h1 type veth peer name eth2a netns h2

# Assign IP addresses for wired connection
ip -n h1 addr add 10.0.0.1/24 dev eth1a
ip -n h2 addr add 10.0.0.2/24 dev eth2a

# Setup wireless interfaces
setup_wireless h1 0 "mptcp_test" 2412 "192.168.1.1"
setup_wireless h2 1 "mptcp_test" 2412 "192.168.1.2"

# Set traffic control
# Wired link
ip netns exec h1 tc qdisc add dev eth1a root netem delay 5ms rate 10mbit
ip netns exec h2 tc qdisc add dev eth2a root netem delay 5ms rate 10mbit

# Wireless link
ip netns exec h1 tc qdisc add dev wlan0 root netem delay 10ms rate 5mbit loss 1%
ip netns exec h2 tc qdisc add dev wlan1 root netem delay 10ms rate 5mbit loss 1%

# Enable all interfaces
ip -n h1 link set lo up
ip -n h2 link set lo up
ip -n h1 link set eth1a up
ip -n h2 link set eth2a up

# Configure MPTCP
ip -n h1 mptcp endpoint flush
ip -n h2 mptcp endpoint flush

ip -n h1 mptcp limits set subflow 2 add_addr_accepted 2
ip -n h2 mptcp limits set subflow 2 add_addr_accepted 2

# Add MPTCP endpoints
ip -n h1 mptcp endpoint add 10.0.0.1 dev eth1a id 1 signal
ip -n h1 mptcp endpoint add 192.168.1.1 dev wlan0 id 2 signal

ip -n h2 mptcp endpoint add 10.0.0.2 dev eth2a id 1 signal
ip -n h2 mptcp endpoint add 192.168.1.2 dev wlan1 id 2 signal

# Set up routing
ip netns exec h1 ip route add default scope global \
    nexthop via 10.0.0.2 dev eth1a weight 1 \
    nexthop via 192.168.1.2 dev wlan0 weight 1

ip netns exec h2 ip route add default scope global \
    nexthop via 10.0.0.1 dev eth2a weight 1 \
    nexthop via 192.168.1.1 dev wlan1 weight 1

# Print status
echo "=== MPTCP Configuration Status ==="
echo "H1 endpoints:"
ip netns exec h1 ip mptcp endpoint show
echo -e "\nH2 endpoints:"
ip netns exec h2 ip mptcp endpoint show

# Print interface status
echo -e "\n=== Interface Status ==="
echo "H1 interfaces:"
ip netns exec h1 ip addr show
echo -e "\nH2 interfaces:"
ip netns exec h2 ip addr show