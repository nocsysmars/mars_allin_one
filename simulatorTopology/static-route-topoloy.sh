#!/bin/bash

# Network Topology Setup Script
# Gateway (OVS) + 4 Switches (OVS) + 9 Hosts (Docker) + 1 External Host via h9 router
# Each switch has 2 hosts + 1 host on gateway
# h10 connects to h9 via veth pair (h9 routes 11.11.11.0/24)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Configuration
CONTROLLER_IP="192.168.42.11"  # Change to your controller IP
CONTROLLER_PORT=6653

# Host to switch mapping
declare -A HOST_SWITCH_MAP=(
    ["h1-sw1"]="sw1"
    ["h2-sw1"]="sw1"
    ["h3-sw2"]="sw2"
    ["h4-sw2"]="sw2"
    ["h5-sw3"]="sw3"
    ["h6-sw3"]="sw3"
    ["h7-sw4"]="sw4"
    ["h8-sw4"]="sw4"
    ["h9-gw"]="gw"
)

# IP addresses for hosts
declare -A HOST_IPS=(
    ["h1-sw1"]="10.0.1.2/24"
    ["h2-sw1"]="10.0.1.3/24"
    ["h3-sw2"]="10.0.2.2/24"
    ["h4-sw2"]="10.0.2.3/24"
    ["h5-sw3"]="10.0.3.2/24"
    ["h6-sw3"]="10.0.3.3/24"
    ["h7-sw4"]="10.0.4.2/24"
    ["h8-sw4"]="10.0.4.3/24"
    ["h9-gw"]="10.0.0.2/24"
)

# Gateway IPs per subnet
GW_IPS=(
    "10.0.0.1/24"
    "10.0.1.1/24"
    "10.0.2.1/24"
    "10.0.3.1/24"
    "10.0.4.1/24"
)

echo -e "${GREEN}=== Network Topology Setup ===${NC}"
echo -e "${YELLOW}Gateway: gw (OVS)${NC}"
echo -e "${YELLOW}Switches: sw1, sw2, sw3, sw4 (OVS)${NC}"
echo -e "${YELLOW}Hosts: 9 Docker containers (2 per switch + 1 on gw) + h10 via h9 router${NC}"
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
    docker stop h10 2>/dev/null || true
    docker rm h10 2>/dev/null || true
    
    # Delete OVS bridges
    for bridge in gw sw1 sw2 sw3 sw4; do
        ovs-vsctl --if-exists del-br $bridge
    done
    
    # Clean up any leftover veth interfaces
    for veth in $(ip link show 2>/dev/null | grep -oE 'veth[0-9]+|vh[0-9]+|vb[0-9]+|gw-sw[0-9]+|sw[0-9]+-gw|h9-h10|h10-h9' | sort -u); do
        ip link delete $veth 2>/dev/null || true
    done
    
    # Clean up namespace symlinks
    rm -f /var/run/netns/docker-* 2>/dev/null || true
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Function to create OVS bridges and connect to controller
create_ovs_bridges() {
    echo -e "${YELLOW}Creating OVS bridges...${NC}"
    
    # Create gateway bridge
    ovs-vsctl add-br gw
    ovs-vsctl set bridge gw protocols=OpenFlow13
    ovs-vsctl set bridge gw other-config:datapath-id=0000000000000001
    ovs-vsctl set-controller gw tcp:$CONTROLLER_IP:$CONTROLLER_PORT
    ovs-vsctl set controller gw inactivity_probe=120000
    ovs-vsctl set controller gw max_backoff=10000
    ovs-vsctl set controller gw connection-mode=out-of-band
    ovs-vsctl set-fail-mode gw secure
    echo -e "${GREEN}✓ Gateway bridge 'gw' created${NC}"
    
    # Create switch bridges
    for i in {1..4}; do
        ovs-vsctl add-br sw$i
        ovs-vsctl set bridge sw$i protocols=OpenFlow13
        ovs-vsctl set bridge sw$i other-config:datapath-id=000000000000000$((i+1))
        ovs-vsctl set-controller sw$i tcp:$CONTROLLER_IP:$CONTROLLER_PORT
        ovs-vsctl set controller sw$i inactivity_probe=120000
        ovs-vsctl set controller sw$i connection-mode=out-of-band
        ovs-vsctl set-fail-mode sw$i secure
        echo -e "${GREEN}✓ Switch bridge 'sw$i' created${NC}"
    done
    
    # Create veth links between gateway and switches
    echo -e "${YELLOW}Creating veth links between gateway and switches...${NC}"
    for i in {1..4}; do
        ip link add gw-sw$i type veth peer name sw$i-gw
        ip link set gw-sw$i up
        ip link set sw$i-gw up
        ovs-vsctl add-port gw gw-sw$i
        ovs-vsctl add-port sw$i sw$i-gw
        echo -e "${GREEN}✓ Connected gw <-> sw$i (veth pair)${NC}"
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
    nsenter -t $pid -n ip link set eth0 up
    nsenter -t $pid -n ip addr add $ip_addr dev eth0
    
    # Add default route through gateway
    local gateway_ip=$(echo $ip_addr | cut -d'.' -f1-3).1
    nsenter -t $pid -n ip route add default via $gateway_ip dev eth0
    
    # Bring up the other end of veth
    ip link set $veth_br up
    
    return 0
}

# Function to create Docker hosts and connect to switches
create_docker_hosts() {
    echo -e "${YELLOW}Creating Docker hosts...${NC}"
    
    # Counter for unique veth naming
    veth_counter=0
    
    for hostname in "${!HOST_SWITCH_MAP[@]}"; do
        switch=${HOST_SWITCH_MAP[$hostname]}
        ip_addr=${HOST_IPS[$hostname]}
        
        echo -e "Creating $hostname connected to $switch"
        
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
        if attach_veth_to_container $hostname $veth_host $veth_br $ip_addr; then
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

# Function to configure gateway interfaces
configure_gateway() {
    echo -e "${YELLOW}Configuring gateway interfaces...${NC}"
    
    # Create internal ports on gateway for each subnet
    for i in {0..4}; do
        int_port="gw-int$i"
        
        # Remove if exists
        ovs-vsctl --if-exists del-port gw $int_port || true
        
        # Add port
        ovs-vsctl add-port gw $int_port -- set interface $int_port type=internal
        
        # Wait for interface to appear
        sleep 0.3
        
        # Clear any existing IP on this interface
        ip addr flush dev $int_port 2>/dev/null || true
        
        # Bring interface up and assign IP
        ip link set $int_port up 2>/dev/null || true
        ip addr add ${GW_IPS[$i]} dev $int_port 2>/dev/null || true
        
        echo -e "${GREEN}✓ Gateway interface $int_port configured with ${GW_IPS[$i]}${NC}"
    done
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true
    
    # Optional: Add NAT/masquerade if gateway should provide internet access
    if ip route | grep -q default; then
        ext_iface=$(ip route | grep default | awk '{print $5}' | head -1)
        if [ -n "$ext_iface" ]; then
            # Check if rule already exists
            if ! iptables -t nat -C POSTROUTING -s 10.0.0.0/8 -o $ext_iface -j MASQUERADE 2>/dev/null; then
                iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o $ext_iface -j MASQUERADE
                echo -e "${GREEN}✓ NAT masquerading enabled for outbound traffic${NC}"
            fi
        fi
    fi
}

# Function to verify connectivity
verify_connectivity() {
    echo -e "${YELLOW}Verifying setup...${NC}"
    
    # Check if OVS bridges are up
    for bridge in gw sw1 sw2 sw3 sw4; do
        if ovs-vsctl br-exists $bridge; then
            echo -e "${GREEN}✓ Bridge $bridge exists${NC}"
            # Check controller connection status
            is_connected=$(ovs-vsctl show | grep -A3 "Bridge \"$bridge\"" | grep "is_connected" || true)
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
    for bridge in gw sw1 sw2 sw3 sw4; do
        connected=$(ovs-vsctl show 2>/dev/null | grep -A5 "Bridge \"$bridge\"" | grep "is_connected: true" || true)
        if [ -n "$connected" ]; then
            echo -e "${GREEN}??$bridge connected to controller${NC}"
        else
            echo -e "${RED}??$bridge NOT connected to controller - check controller is running at $CONTROLLER_IP:$CONTROLLER_PORT${NC}"
        fi
    done
    
    # Check if containers are running
    for host in "${!HOST_SWITCH_MAP[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^$host$"; then
            # Test if container has network configured
            pid=$(docker inspect -f '{{.State.Pid}}' $host 2>/dev/null)
            if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                ip_addr=$(nsenter -t $pid -n ip addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
                if [ -n "$ip_addr" ]; then
                    echo -e "${GREEN}✓ $host has IP $ip_addr${NC}"
                else
                    echo -e "${RED}✗ $host has no IP configured${NC}"
                fi
            else
                echo -e "${RED}✗ $host not running properly${NC}"
            fi
        else
            echo -e "${RED}✗ $host container not found${NC}"
        fi
    done
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
    for br in gw sw1 sw2 sw3 sw4; do
        controller=$(ovs-vsctl get-controller $br 2>/dev/null || echo "No controller")
        echo "$br: $controller"
    done
    echo ""
    echo -e "${YELLOW}Running Docker Hosts:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "h[0-9]-sw[0-9]" || echo "  No hosts found"
    echo ""
    echo -e "${YELLOW}Network Configuration:${NC}"
    for host in "${!HOST_SWITCH_MAP[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^$host$"; then
            pid=$(docker inspect -f '{{.State.Pid}}' $host 2>/dev/null || true)
            if [ -n "$pid" ] && [ "$pid" != "0" ] && [ -d /proc/$pid/ns ]; then
                ip_addr=$(nsenter -t $pid -n ip addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
                route=$(nsenter -t $pid -n ip route show default 2>/dev/null)
                echo "  $host: $ip_addr, gateway: $route"
            else
                echo "  $host: Container not ready"
            fi
        fi
    done
    echo ""
    echo -e "${GREEN}Controller will be connected to: tcp:$CONTROLLER_IP:$CONTROLLER_PORT${NC}"
    echo -e "${YELLOW}Note: Make sure your controller is running at $CONTROLLER_IP:$CONTROLLER_PORT${NC}"
    echo ""
    echo -e "${YELLOW}To test connectivity (after controller is up):${NC}"
    echo "  # Test host to gateway connectivity"
    echo "  docker exec h1-sw1 ping -c 3 10.0.1.1"
    echo ""
    echo "  # Test host to host on same switch"
    echo "  docker exec h1-sw1 ping -c 3 10.0.1.3"
    echo ""
    echo "  # Test host to host across different switches"
    echo "  docker exec h1-sw1 ping -c 3 10.0.2.2"
    echo ""
    echo "  # Check OVS flows (if controller is running)"
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
                echo "  --controller IP    Set controller IP (default: 192.168.100.100)"
                echo "  --port PORT        Set controller port (default: 6633)"
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
    #configure_gateway
    verify_connectivity
    display_topology
    
    echo -e "${GREEN}Setup complete!${NC}"
}

main "$@"

# === Post-setup: Create h10 connected to h9 via veth pair ===
# h9 acts as a router between OVS network and h10's 11.11.11.0/24 subnet

# Create h10 container
docker rm -f h10 2>/dev/null || true
docker run -d --name h10 --cap-add=NET_ADMIN --network none alpine:latest sleep infinity > /dev/null

# Get PIDs
H9_PID=$(docker inspect -f '{{.State.Pid}}' h9-gw)
H10_PID=$(docker inspect -f '{{.State.Pid}}' h10)

# Create netns symlinks
mkdir -p /var/run/netns
ln -sf /proc/$H9_PID/ns/net /var/run/netns/docker-h9-gw
ln -sf /proc/$H10_PID/ns/net /var/run/netns/docker-h10

# Create veth pair between h9 and h10
ip link add h9-h10 type veth peer name h10-h9

# Move h9-h10 into h9's namespace
ip link set h9-h10 netns docker-h9-gw

# Move h10-h9 into h10's namespace
ip link set h10-h9 netns docker-h10

# Configure h9 side: 11.11.11.254/24 (gateway for h10)
nsenter -t $H9_PID -n ip link set h9-h10 up
nsenter -t $H9_PID -n ip addr add 11.11.11.254/24 dev h9-h10

# Enable IP forwarding in h9
nsenter -t $H9_PID -n sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Configure h10 side: 11.11.11.1/24 with gateway 11.11.11.254
nsenter -t $H10_PID -n ip link set h10-h9 up
nsenter -t $H10_PID -n ip addr add 11.11.11.1/24 dev h10-h9
nsenter -t $H10_PID -n ip route add default via 11.11.11.254 dev h10-h9

# Add route on h9 for return traffic from 10.0.x.x subnets
# h9 already has 10.0.0.2/24 on eth0 with default route via 10.0.0.1
# Traffic from other subnets to 11.11.11.0/24 will come via gw → h9 → h10

# Add additional IP on h9's eth0 for gateway connectivity
docker exec h9-gw ip addr add dev eth0 12.12.12.2/24
docker exec h9-gw ip route del default via 10.0.0.1
docker exec h9-gw ip route add default via 12.12.12.1

#                   11.11.11.0/24
#                   ┌──────────┐
#                   │   h10    │ 11.11.11.1
#                   └────┬─────┘
#                        │ veth (h10-h9 ↔ h9-h10)
#                   ┌────┴─────┐
#                   │  h9-gw   │ 11.11.11.254 (router) + 12.12.12.2
#                   └────┬─────┘
#                        │ eth0
#                   ┌────┴─────┐
#                   │    gw    │ (OVS spine)
#              ┌────┼────┬─────┼────┐
#              │    │    │     │    │
#             sw1  sw2  sw3  sw4
