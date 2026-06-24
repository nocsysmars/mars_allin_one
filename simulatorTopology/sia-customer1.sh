#!/bin/bash

# Network Topology Setup Script
# Gateway (OVS) + 14 Switches (OVS) + 93 Hosts (Docker)
# Gateway switch: 000080a2353b45d5
# 14 regular switches + hosts randomly distributed
# Hosts connected via Docker containers with custom MAC addresses

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Configuration
CONTROLLER_IP="192.168.42.11"  # Change to your controller IP
CONTROLLER_PORT=6653

# Switch datapath IDs and names
declare -A SWITCH_DPID=(
    ["sw1"]="0000b86a9728a980"
    ["sw2"]="0000b86a97145220"
    ["sw3"]="0000b86a97145140"
    ["sw4"]="0000b86a97145180"
    ["sw5"]="0000b86a970c0140"
    ["sw6"]="0000b86a970c0340"
    ["sw7"]="00003c2c99885480"
    ["gw"]="000080a2353b45d5"
    ["sw8"]="0000b86a97f05980"
    ["sw9"]="0000b86a97145120"
    ["sw10"]="0000b86a971451e0"
    ["sw11"]="00003c2c99885520"
    ["sw12"]="0000b86a97f05840"
    ["sw13"]="00003c2c9902c0c0"
    ["sw14"]="0000b86a9728a240"
)

ALL_SWITCHES=("sw1" "sw2" "sw3" "sw4" "sw5" "sw6" "sw7" "sw8" "sw9" "sw10" "sw11" "sw12" "sw13" "sw14" "gw")
REGULAR_SWITCHES=("sw1" "sw2" "sw3" "sw4" "sw5" "sw6" "sw7" "sw8" "sw9" "sw10" "sw11" "sw12" "sw13" "sw14")

# Host MAC addresses and their assigned switches (randomly distributed)
# Format: HOST_MAC_MAP[hostname]="MAC_ADDRESS"
# Format: HOST_SWITCH_MAP[hostname]="switch_name"

declare -A HOST_MAC_MAP=(
    ["h1"]="00:30:D6:14:B7:52"
    ["h2"]="3C:2C:99:1E:37:D7"
    ["h3"]="00:22:46:02:5A:A2"
    ["h4"]="00:0E:C6:56:0A:AE"
    ["h5"]="38:68:DD:1B:AA:D0"
    ["h6"]="00:30:D6:14:B7:4D"
    ["h7"]="8E:57:FF:4B:A2:3F"
    ["h8"]="A4:17:91:01:E9:AF"
    ["h9"]="44:87:FC:DB:20:07"
    ["h10"]="00:0E:C6:62:C9:22"
    ["h11"]="28:63:36:9B:3C:BF"
    ["h12"]="08:94:EF:7A:3A:F7"
    ["h13"]="28:63:36:A1:69:88"
    ["h14"]="08:94:EF:7A:23:D6"
    ["h15"]="FC:1B:D1:86:FF:78"
    ["h16"]="1C:69:7A:52:EA:DB"
    ["h17"]="00:30:D6:14:B7:42"
    ["h18"]="14:DA:E9:22:4D:FA"
    ["h19"]="C4:00:AD:0A:EB:99"
    ["h20"]="F4:8E:38:B0:A8:4C"
    ["h21"]="00:0E:C6:66:F3:91"
    ["h22"]="4C:CC:6A:C1:F9:03"
    ["h23"]="28:63:36:A1:E2:D2"
    ["h24"]="38:68:DD:1D:BC:10"
    ["h25"]="00:0B:AB:AA:C0:62"
    ["h26"]="B0:51:8E:F6:45:D8"
    ["h27"]="38:68:DD:1D:BF:48"
    ["h28"]="94:C6:91:D7:23:57"
    ["h29"]="E0:DC:A0:42:52:EA"
    ["h30"]="EC:89:14:A7:A8:A3"
    ["h31"]="00:1E:FB:72:01:6C"
    ["h32"]="00:90:0B:81:B1:05"
    ["h33"]="00:0E:C6:66:F3:F1"
    ["h34"]="44:37:E6:2A:BC:0F"
    ["h35"]="44:37:E6:D4:B7:24"
    ["h36"]="38:68:DD:1B:96:68"
    ["h37"]="44:87:FC:D9:47:D5"
    ["h38"]="00:0E:C6:62:C6:F1"
    ["h39"]="00:0E:C6:A1:CF:4A"
    ["h40"]="00:1E:90:B2:D2:B0"
    ["h41"]="44:87:FC:C4:EF:97"
    ["h42"]="BC:30:5B:AC:36:B3"
    ["h43"]="D8:CB:8A:2A:2E:60"
    ["h44"]="E8:9A:8F:2D:7E:E8"
    ["h45"]="0E:30:DE:4A:17:3F"
    ["h46"]="00:1C:06:32:21:71"
    ["h47"]="E0:BE:03:10:48:62"
    ["h48"]="00:80:2F:25:77:AC"
    ["h49"]="00:0E:C6:62:C9:29"
    ["h50"]="E0:BE:03:10:4F:3D"
    ["h51"]="90:33:CE:4A:2C:7F"
    ["h52"]="00:19:21:B2:15:D2"
    ["h53"]="C0:3F:D5:92:80:9E"
    ["h54"]="00:21:97:36:A5:10"
    ["h55"]="28:63:36:9D:74:8F"
    ["h56"]="00:0B:AB:B2:5C:3D"
    ["h57"]="00:0B:AB:DA:65:AE"
    ["h58"]="6E:D5:74:20:E9:E2"
    ["h60"]="00:22:46:2B:BE:4A"
    ["h61"]="00:0C:29:05:F1:1B"
    ["h62"]="00:80:2F:25:77:AB"
    ["h63"]="00:21:97:36:69:B3"
    ["h64"]="00:50:C2:34:6D:CD"
    ["h65"]="00:1B:B9:DB:FB:C4"
    ["h66"]="1C:69:7A:52:DD:F7"
    ["h67"]="00:E0:4C:38:DA:EB"
    ["h68"]="94:C6:91:72:19:D4"
    ["h70"]="00:0C:29:04:D2:94"
    ["h71"]="00:50:C2:32:BC:A7"
    ["h72"]="D8:CB:8A:65:33:19"
    ["h73"]="38:68:DD:1B:87:8B"
    ["h74"]="7C:05:07:6D:C1:50"
    ["h75"]="44:37:E6:32:6E:17"
    ["h76"]="30:B4:9E:56:2B:F8"
    ["h77"]="44:87:FC:A4:80:8C"
    ["h78"]="10:76:2E:49:0F:7F"
    ["h79"]="00:42:43:01:42:37"
    ["h80"]="00:1C:06:32:16:70"
    ["h81"]="AC:16:2D:7C:07:68"
    ["h82"]="94:18:82:35:9A:D0"
    ["h84"]="A4:17:91:01:FF:BB"
    ["h85"]="00:30:D6:14:B7:4F"
    ["h86"]="94:C6:91:DA:8C:90"
    ["h87"]="14:DA:E9:22:4E:00"
    ["h88"]="00:0C:29:6C:E7:9F"
    ["h89"]="00:42:43:01:42:38"
    ["h90"]="94:18:82:35:9A:D3"
    ["h91"]="28:63:36:FD:D7:78"
    ["h92"]="00:21:97:37:26:02"
    ["h93"]="E0:BE:03:10:4C:55"
)

# Randomly distribute hosts across switches
# ~6-7 hosts per switch (93 hosts / 15 switches)
declare -A HOST_SWITCH_MAP=(
    ["h1"]="sw1"
    ["h2"]="sw1"
    ["h3"]="sw1"
    ["h4"]="sw1"
    ["h5"]="sw1"
    ["h6"]="sw1"
    ["h7"]="sw2"
    ["h8"]="sw2"
    ["h9"]="sw2"
    ["h10"]="sw2"
    ["h11"]="sw2"
    ["h12"]="sw2"
    ["h13"]="sw3"
    ["h14"]="sw3"
    ["h15"]="sw3"
    ["h16"]="sw3"
    ["h17"]="sw3"
    ["h18"]="sw3"
    ["h19"]="sw4"
    ["h20"]="sw4"
    ["h21"]="sw4"
    ["h22"]="sw4"
    ["h23"]="sw4"
    ["h24"]="sw4"
    ["h25"]="sw5"
    ["h26"]="gw"
    ["h27"]="sw5"
    ["h28"]="sw5"
    ["h29"]="sw5"
    ["h30"]="sw5"
    ["h31"]="sw6"
    ["h32"]="gw"
    ["h33"]="sw6"
    ["h34"]="sw6"
    ["h35"]="sw6"
    ["h36"]="sw6"
    ["h37"]="sw7"
    ["h38"]="sw7"
    ["h39"]="sw7"
    ["h40"]="sw7"
    ["h41"]="sw7"
    ["h42"]="sw7"
    ["h43"]="sw8"
    ["h44"]="sw8"
    ["h45"]="sw8"
    ["h46"]="sw8"
    ["h47"]="sw8"
    ["h48"]="sw8"
    ["h49"]="sw9"
    ["h50"]="sw9"
    ["h51"]="sw9"
    ["h52"]="sw9"
    ["h53"]="sw9"
    ["h54"]="sw9"
    ["h55"]="sw10"
    ["h56"]="sw10"
    ["h57"]="sw10"
    ["h58"]="gw"
    ["h60"]="sw10"
    ["h61"]="sw11"
    ["h62"]="sw11"
    ["h63"]="sw11"
    ["h64"]="sw11"
    ["h65"]="gw"
    ["h66"]="sw11"
    ["h67"]="sw12"
    ["h68"]="sw12"
    ["h70"]="sw12"
    ["h71"]="sw12"
    ["h72"]="sw12"
    ["h73"]="sw13"
    ["h74"]="sw13"
    ["h75"]="sw13"
    ["h76"]="sw13"
    ["h77"]="sw13"
    ["h78"]="sw13"
    ["h79"]="sw13"
    ["h80"]="sw14"
    ["h81"]="sw14"
    ["h82"]="sw14"
    ["h84"]="sw14"
    ["h85"]="sw14"
    ["h86"]="gw"
    ["h87"]="gw"
    ["h88"]="gw"
    ["h89"]="gw"
    ["h90"]="gw"
    ["h91"]="gw"
    ["h92"]="gw"
    ["h93"]="gw"
)

# IP addresses for hosts (from JSON config host descriptions)
declare -A HOST_IPS=(
    ["h1"]="192.168.1.215/24"
    ["h2"]="192.168.0.1/24"
    ["h3"]="192.168.10.8/24"
    ["h4"]="192.168.0.169/24"
    ["h5"]="192.168.254.1/24"
    ["h6"]="192.168.1.216/24"
    ["h7"]="192.168.1.199/24"
    ["h8"]="192.168.0.205/24"
    ["h9"]="192.168.8.14/24"
    ["h10"]="192.168.10.7/24"
    ["h11"]="192.168.0.54/24"
    ["h12"]="192.168.0.144/24"
    ["h13"]="192.168.0.25/24"
    ["h14"]="192.168.254.7/24"
    ["h15"]="192.168.1.253/24"
    ["h16"]="192.168.5.2/24"
    ["h17"]="192.168.1.217/24"
    ["h18"]="192.168.0.15/24"
    ["h19"]="192.168.0.81/24"
    ["h20"]="192.168.2.9/24"
    ["h21"]="192.168.0.4/24"
    ["h22"]="192.168.1.99/24"
    ["h23"]="192.168.0.26/24"
    ["h24"]="192.168.254.4/24"
    ["h25"]="192.168.0.2/24"
    ["h26"]="192.168.252.2/24"
    ["h27"]="192.168.254.2/24"
    ["h28"]="192.168.8.19/24"
    ["h29"]="192.168.0.61/24"
    ["h30"]="192.168.1.102/24"
    ["h31"]="192.168.0.250/24"
    ["h32"]="192.168.252.3/24"
    ["h33"]="192.168.0.5/24"
    ["h34"]="192.168.8.18/24"
    ["h35"]="192.168.8.16/24"
    ["h36"]="192.168.254.6/24"
    ["h37"]="192.168.8.4/24"
    ["h38"]="192.168.2.5/24"
    ["h39"]="192.168.0.3/24"
    ["h40"]="192.168.8.26/24"
    ["h41"]="192.168.0.145/24"
    ["h42"]="192.168.8.2/24"
    ["h43"]="192.168.8.11/24"
    ["h44"]="192.168.0.167/24"
    ["h45"]="192.168.1.196/24"
    ["h46"]="192.168.0.51/24"
    ["h47"]="192.168.0.76/24"
    ["h48"]="192.168.9.3/24"
    ["h49"]="192.168.0.6/24"
    ["h50"]="192.168.17.211/24"
    ["h51"]="192.168.1.198/24"
    ["h52"]="192.168.8.24/24"
    ["h53"]="192.168.8.9/24"
    ["h54"]="192.168.8.21/24"
    ["h55"]="192.168.0.53/24"
    ["h56"]="192.168.0.28/24"
    ["h57"]="192.168.0.48/24"
    ["h58"]="192.168.1.101/24"
    ["h60"]="192.168.0.168/24"
    ["h61"]="192.168.0.212/24"
    ["h62"]="192.168.9.2/24"
    ["h63"]="192.168.8.23/24"
    ["h64"]="192.168.2.3/24"
    ["h65"]="192.168.8.25/24"
    ["h66"]="192.168.10.2/24"
    ["h67"]="192.168.8.17/24"
    ["h68"]="192.168.1.52/24"
    ["h70"]="192.168.0.210/24"
    ["h71"]="192.168.2.2/24"
    ["h72"]="192.168.8.13/24"
    ["h73"]="192.168.254.3/24"
    ["h74"]="192.168.9.5/24"
    ["h75"]="192.168.8.5/24"
    ["h76"]="192.168.1.1/24"
    ["h77"]="192.168.10.6/24"
    ["h78"]="192.168.1.197/24"
    ["h79"]="192.168.3.3/24"
    ["h80"]="192.168.0.52/24"
    ["h81"]="192.168.8.200/24"
    ["h82"]="192.168.1.100/24"
    ["h84"]="192.168.0.206/24"
    ["h85"]="192.168.1.214/24"
    ["h86"]="192.168.0.100/24"
    ["h87"]="192.168.0.203/24"
    ["h88"]="192.168.0.208/24"
    ["h89"]="192.168.3.2/24"
    ["h90"]="192.168.1.127/24"
    ["h91"]="192.168.0.60/24"
    ["h92"]="192.168.8.3/24"
    ["h93"]="192.168.0.70/24"
)

echo -e "${GREEN}=== Network Topology Setup ===${NC}"
echo -e "${YELLOW}Gateway: gw (OVS, spine)${NC}"
echo -e "${YELLOW}Switches: sw1-sw14 (OVS, leaf)${NC}"
echo -e "${YELLOW}Hosts: 93 Docker containers${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Function to check if OVS is installed
check_ovs() {
    if ! command -v ovs-vsctl &> /dev/null; then
        echo -e "${RED}Open vSwitch not found. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Open vSwitch found${NC}"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker found${NC}"
}

# Function to cleanup existing setup
cleanup() {
    echo -e "${YELLOW}Cleaning up existing topology...${NC}"

    # Stop and remove Docker containers
    for host in "${!HOST_SWITCH_MAP[@]}"; do
        docker stop $host 2>/dev/null || true
        docker rm $host 2>/dev/null || true
    done

    # Delete OVS bridges
    for bridge in "${ALL_SWITCHES[@]}"; do
        ovs-vsctl --if-exists del-br $bridge
    done

    # Clean up any leftover veth interfaces
    for veth in $(ip link show 2>/dev/null | grep -oE 'vh[0-9]+|vb[0-9]+|gw-sw[0-9]+|sw[0-9]+-gw' | sort -u); do
        ip link delete $veth 2>/dev/null || true
    done

    # Clean up namespace symlinks
    rm -f /var/run/netns/docker-* 2>/dev/null || true

    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Function to create OVS bridges and connect to controller
create_ovs_bridges() {
    echo -e "${YELLOW}Creating OVS bridges...${NC}"

    for sw_name in "${ALL_SWITCHES[@]}"; do
        local dpid="${SWITCH_DPID[$sw_name]}"

        ovs-vsctl add-br $sw_name
        ovs-vsctl set bridge $sw_name protocols=OpenFlow13
        ovs-vsctl set bridge $sw_name other-config:datapath-id=$dpid
        ovs-vsctl set-controller $sw_name tcp:$CONTROLLER_IP:$CONTROLLER_PORT
        ovs-vsctl set controller $sw_name inactivity_probe=120000
        ovs-vsctl set controller $sw_name max_backoff=10000
        ovs-vsctl set controller $sw_name connection-mode=out-of-band
        ovs-vsctl set-fail-mode $sw_name secure
        echo -e "${GREEN}✓ Bridge '$sw_name' created (dpid=$dpid)${NC}"
    done

    # Create veth links between gateway and leaf switches
    echo -e "${YELLOW}Creating veth links between gw and leaf switches...${NC}"
    for sw_name in "${REGULAR_SWITCHES[@]}"; do
        ip link add gw-${sw_name} type veth peer name ${sw_name}-gw
        ip link set gw-${sw_name} up
        ip link set ${sw_name}-gw up
        ovs-vsctl add-port gw gw-${sw_name}
        ovs-vsctl add-port ${sw_name} ${sw_name}-gw
        echo -e "${GREEN}✓ Connected gw <-> ${sw_name} (veth pair)${NC}"
    done
}

# Function to setup network namespace for Docker container
setup_docker_namespace() {
    local container_name=$1
    local pid=$2

    # Create /var/run/netns if it doesn't exist
    mkdir -p /var/run/netns

    # Create symlink for the container's network namespace
    ln -sf /proc/$pid/ns/net /var/run/netns/docker-$container_name

    echo "docker-$container_name"
}

# Function to attach veth to container using nsenter
attach_veth_to_container() {
    local container_name=$1
    local veth_host=$2
    local veth_br=$3
    local ip_addr=$4
    local mac_addr=$5

    # Get container PID
    local pid=$(docker inspect -f '{{.State.Pid}}' $container_name 2>/dev/null)

    if [ -z "$pid" ] || [ "$pid" == "0" ]; then
        echo -e "${RED}Error: Cannot get PID for container $container_name${NC}"
        return 1
    fi

    # Wait for container to be fully initialized
    local max_attempts=20
    local attempt=0
    while [ ! -d /proc/$pid/ns ] && [ $attempt -lt $max_attempts ]; do
        sleep 0.2
        attempt=$((attempt + 1))
    done

    if [ ! -d /proc/$pid/ns ]; then
        echo -e "${RED}Error: Cannot find namespace for container $container_name (PID: $pid)${NC}"
        return 1
    fi

    # Setup namespace symlink for nsenter
    local netns_name=$(setup_docker_namespace $container_name $pid)

    # Move veth to container's namespace
    ip link set $veth_host netns $netns_name

    # Configure network inside container using nsenter
    nsenter -t $pid -n ip link set dev $veth_host name eth0
    nsenter -t $pid -n ip link set dev eth0 address $mac_addr
    nsenter -t $pid -n ip link set eth0 up
    nsenter -t $pid -n ip addr add $ip_addr dev eth0

    # Add default route through gateway
    local gateway_ip=$(echo $ip_addr | cut -d'.' -f1-3).1
    nsenter -t $pid -n ip route add default via $gateway_ip dev eth0 2>/dev/null || true

    # Bring up the other end of veth
    ip link set $veth_br up

    return 0
}

# Function to create Docker hosts and connect to switches
create_docker_hosts() {
    echo -e "${YELLOW}Creating Docker hosts...${NC}"

    # Counter for unique veth naming
    veth_counter=0

    for hostname in $(echo "${!HOST_SWITCH_MAP[@]}" | tr ' ' '\n' | sort -V); do
        switch=${HOST_SWITCH_MAP[$hostname]}
        ip_addr=${HOST_IPS[$hostname]}
        mac_addr=${HOST_MAC_MAP[$hostname]}

        echo -e "Creating $hostname connected to $switch (MAC: $mac_addr, IP: $ip_addr)"

        # Check if container already exists and remove it
        docker rm -f $hostname 2>/dev/null || true

        # Create a Docker container with network isolation
        docker run -d \
            --name $hostname \
            --cap-add=NET_ADMIN \
            --network none \
            alpine:latest \
            sleep infinity > /dev/null

        # Give container time to initialize
        sleep 0.3

        # Create veth pair with shorter names
        veth_counter=$((veth_counter + 1))
        veth_host="vh$veth_counter"
        veth_br="vb$veth_counter"

        # Create veth pair
        ip link add $veth_host type veth peer name $veth_br

        # Attach veth to container
        if attach_veth_to_container $hostname $veth_host $veth_br $ip_addr $mac_addr; then
            # Connect other end to OVS bridge
            ovs-vsctl add-port $switch $veth_br
            echo -e "${GREEN}  ✓ $hostname connected to $switch with IP $ip_addr${NC}"
        else
            echo -e "${RED}  ✗ Failed to connect $hostname${NC}"
            # Clean up veth
            ip link delete $veth_host 2>/dev/null || true
        fi
    done
}

# Function to verify connectivity
verify_connectivity() {
    echo -e "${YELLOW}Verifying setup...${NC}"

    # Check if OVS bridges are up
    for bridge in "${ALL_SWITCHES[@]}"; do
        if ovs-vsctl br-exists $bridge; then
            echo -e "${GREEN}✓ Bridge $bridge exists${NC}"
            controller=$(ovs-vsctl get-controller $bridge 2>/dev/null)
            echo -e "    Controller: $controller"
        else
            echo -e "${RED}✗ Bridge $bridge missing${NC}"
        fi
    done

    # Wait a moment for OpenFlow connections to establish
    echo -e "${YELLOW}Waiting for OpenFlow connections (5s)...${NC}"
    sleep 5

    # Verify OpenFlow connection status
    for bridge in "${ALL_SWITCHES[@]}"; do
        connected=$(ovs-vsctl show 2>/dev/null | grep -A5 "Bridge \"$bridge\"" | grep "is_connected: true" || true)
        if [ -n "$connected" ]; then
            echo -e "${GREEN}  ✓ $bridge connected to controller${NC}"
        else
            echo -e "${RED}  ✗ $bridge NOT connected to controller - check controller at $CONTROLLER_IP:$CONTROLLER_PORT${NC}"
        fi
    done

    # Check if containers are running
    local running=0
    local failed=0
    for host in $(echo "${!HOST_SWITCH_MAP[@]}" | tr ' ' '\n' | sort -V); do
        if docker ps --format '{{.Names}}' | grep -q "^${host}$"; then
            running=$((running + 1))
        else
            failed=$((failed + 1))
            echo -e "${RED}✗ $host container not found${NC}"
        fi
    done
    echo -e "${GREEN}✓ $running hosts running, $failed failed${NC}"
}

# Function to display topology information
display_topology() {
    echo ""
    echo -e "${GREEN}=== Topology Created Successfully ===${NC}"
    echo ""
    echo -e "${YELLOW}OVS Bridges:${NC}"
    ovs-vsctl list-br
    echo ""
    echo -e "${YELLOW}OVS Bridge Controllers:${NC}"
    for br in "${ALL_SWITCHES[@]}"; do
        controller=$(ovs-vsctl get-controller $br 2>/dev/null || echo "No controller")
        echo "  $br: $controller"
    done
    echo ""
    echo -e "${YELLOW}Running Docker Hosts:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "^h[0-9]" || echo "  No hosts found"
    echo ""
    echo -e "${GREEN}Controller: tcp:$CONTROLLER_IP:$CONTROLLER_PORT${NC}"
    echo -e "${YELLOW}Note: Make sure your controller is running at $CONTROLLER_IP:$CONTROLLER_PORT${NC}"
    echo ""
    echo -e "${YELLOW}To test connectivity (after controller is up):${NC}"
    echo "  docker exec h1 ping -c 3 192.168.1.215"
    echo "  ovs-ofctl dump-flows sw1 --protocols=OpenFlow13"
    echo ""
}

# Main execution
main() {
    check_ovs
    check_docker

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --controller)
                CONTROLLER_IP="$2"
                shift 2
                ;;
            --port)
                CONTROLLER_PORT="$2"
                shift 2
                ;;
            --cleanup)
                cleanup
                exit 0
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --controller IP    Set controller IP (default: $CONTROLLER_IP)"
                echo "  --port PORT        Set controller port (default: $CONTROLLER_PORT)"
                echo "  --cleanup          Clean up existing topology"
                echo "  --help             Show this help message"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    cleanup
    create_ovs_bridges
    create_docker_hosts
    verify_connectivity
    display_topology

    echo -e "${GREEN}Setup complete!${NC}"
}

main "$@"
