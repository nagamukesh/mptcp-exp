# MPTCP Experiment

This repository contains scripts and source files for setting up and testing MPTCP (Multipath TCP).
## Repository Structure
```
.
├── 2-node
│   ├── 2-node.sh
│   ├── mptcp_client.c
│   ├── mptcp_server.c
│
├── 4-node
│   ├── 4-node.sh
│   ├── mptcp_client.c
│   ├── mptcp_server.c
```

## Cloning the Repository
```bash
git clone https://github.com/nagamukesh/mptcp-exp.git
cd mptcp-exp
```

## Installing Requirements
Ensure you have the required dependencies installed before running the scripts:
```bash
sudo apt update
sudo apt install -y iperf3 gcc mptcpize iproute2
```

## Running the 2-Node Setup

### **Using mptcpize**
```bash
cd 2-node
sudo sh 2-node.sh
```
In two separate terminal tabs, run:
```bash
sudo ip netns exec h2 mptcpize run iperf3 -s
```
```bash
sudo ip netns exec h1 mptcpize run iperf3 -c 10.0.0.2
```

### **Using Sockets**
```bash
cd 2-node
sudo sh 2-node.sh
```
Compile the client and server:
```bash
gcc -o mptcp_client mptcp_client.c
gcc -o mptcp_server mptcp_server.c
```
In two separate terminal tabs, run:
```bash
sudo ip netns exec h2 ./mptcp_server
```
```bash
sudo ip netns exec h1 ./mptcp_client
```

## Running the 4-Node Setup

### **Using mptcpize**
```bash
cd 4-node
sudo sh 4-node.sh
```
In two separate terminal tabs, run:
```bash
sudo ip netns exec h2 mptcpize run iperf3 -s
```
```bash
sudo ip netns exec h1 mptcpize run iperf3 -c 10.0.1.2
```

### **Using Sockets**
```bash
cd 4-node
sudo sh 4-node.sh
```
Compile the client and server:
```bash
gcc -o mptcp_client mptcp_client.c
gcc -o mptcp_server mptcp_server.c
```
In two separate terminal tabs, run:
```bash
sudo ip netns exec h2 ./mptcp_server
```
```bash
sudo ip netns exec h1 ./mptcp_client
```

