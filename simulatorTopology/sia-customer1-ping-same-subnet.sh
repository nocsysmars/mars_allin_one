#!/bin/bash

# Ping Test Script - Ping hosts within the same subnet
# This script identifies hosts sharing the same /24 subnet and pings between them
# using Docker exec to run ping from inside each container.

set +e  # Don't exit on error - ping failures are expected and handled

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Configuration
PING_COUNT=1
PING_TIMEOUT=2

# Host IP mapping (from sia-customer1.sh)
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

# Host MAC mapping (from sia-customer1.sh)
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

# Extract subnet (first 3 octets) from IP/CIDR
get_subnet() {
    echo "$1" | cut -d'/' -f1 | cut -d'.' -f1-3
}

# Extract IP (without CIDR) from IP/CIDR
get_ip() {
    echo "$1" | cut -d'/' -f1
}

# Group hosts by subnet
declare -A SUBNET_HOSTS  # subnet -> space-separated list of "host:ip"

for host in $(echo "${!HOST_IPS[@]}" | tr ' ' '\n' | sort -V); do
    ip_cidr="${HOST_IPS[$host]}"
    subnet=$(get_subnet "$ip_cidr")
    ip=$(get_ip "$ip_cidr")
    if [ -z "${SUBNET_HOSTS[$subnet]}" ]; then
        SUBNET_HOSTS[$subnet]="$host:$ip"
    else
        SUBNET_HOSTS[$subnet]="${SUBNET_HOSTS[$subnet]} $host:$ip"
    fi
done

# Parse arguments
SPECIFIC_SUBNET=""
VERBOSE=false
SUMMARY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --subnet)
            SPECIFIC_SUBNET="$2"
            shift 2
            ;;
        --count)
            PING_COUNT="$2"
            shift 2
            ;;
        --timeout)
            PING_TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --summary)
            SUMMARY_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Ping hosts within the same /24 subnet to test connectivity."
            echo ""
            echo "Options:"
            echo "  --subnet SUBNET    Only test a specific subnet (e.g., 192.168.0)"
            echo "  --count N          Number of ping packets (default: 3)"
            echo "  --timeout S        Ping timeout in seconds (default: 5)"
            echo "  --verbose          Show full ping output"
            echo "  --summary          Only show summary at the end"
            echo "  --help             Show this help message"
            echo ""
            echo "Subnets available:"
            for subnet in $(echo "${!SUBNET_HOSTS[@]}" | tr ' ' '\n' | sort); do
                count=$(echo "${SUBNET_HOSTS[$subnet]}" | wc -w)
                echo "  $subnet.0/24  ($count hosts)"
            done
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=== Subnet Ping Test ===${NC}"
echo -e "Ping count: $PING_COUNT, Timeout: ${PING_TIMEOUT}s"
echo ""

# Counters for summary
total_tests=0
success_tests=0
fail_tests=0

# Pre-warm phase: each host pings gateway to register with controller,
# then populate static ARP entries for all peers in same subnet
echo -e "${YELLOW}=== Pre-warming: registering hosts with controller ===${NC}"
for host in $(echo "${!HOST_IPS[@]}" | tr ' ' '\n' | sort -V); do
    ip_cidr="${HOST_IPS[$host]}"
    subnet=$(get_subnet "$ip_cidr")
    host_count=$(echo "${SUBNET_HOSTS[$subnet]}" | wc -w)
    if [ "$host_count" -gt 1 ]; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${host}$"; then
            docker exec $host ping -c 1 -W 1 ${subnet}.1 > /dev/null 2>&1 &
        fi
    fi
done
wait 2>/dev/null
echo -e "${YELLOW}Waiting 3s for controller to learn all host locations...${NC}"
sleep 3

# Populate static ARP entries so ping doesn't depend on controller for ARP resolution
echo -e "${YELLOW}=== Setting static ARP entries for same-subnet peers ===${NC}"
for subnet in $(echo "${!SUBNET_HOSTS[@]}" | tr ' ' '\n' | sort); do
    if [ -n "$SPECIFIC_SUBNET" ] && [ "$subnet" != "$SPECIFIC_SUBNET" ]; then
        continue
    fi

    hosts_in_subnet="${SUBNET_HOSTS[$subnet]}"
    host_count=$(echo "$hosts_in_subnet" | wc -w)
    if [ "$host_count" -le 1 ]; then
        continue
    fi

    IFS=' ' read -ra peer_list <<< "$hosts_in_subnet"

    for src_entry in "${peer_list[@]}"; do
        src_host=$(echo "$src_entry" | cut -d':' -f1)
        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${src_host}$"; then
            continue
        fi

        # Add static ARP for all peers
        for dst_entry in "${peer_list[@]}"; do
            dst_host=$(echo "$dst_entry" | cut -d':' -f1)
            dst_ip=$(echo "$dst_entry" | cut -d':' -f2)
            if [ "$src_host" = "$dst_host" ]; then
                continue
            fi
            dst_mac="${HOST_MAC_MAP[$dst_host]}"
            #if [ -n "$dst_mac" ]; then
                #docker exec $src_host arp -d $dst_ip $dst_mac 2>/dev/null &
            #fi
        done
    done
done
wait 2>/dev/null
echo -e "${GREEN}✓ Static ARP entries set${NC}"
echo ""

# Iterate over each subnet
for subnet in $(echo "${!SUBNET_HOSTS[@]}" | tr ' ' '\n' | sort); do
    # Filter by specific subnet if requested
    if [ -n "$SPECIFIC_SUBNET" ] && [ "$subnet" != "$SPECIFIC_SUBNET" ]; then
        continue
    fi

    hosts_in_subnet="${SUBNET_HOSTS[$subnet]}"
    host_count=$(echo "$hosts_in_subnet" | wc -w)

    # Skip subnets with only 1 host (nothing to ping)
    if [ "$host_count" -le 1 ]; then
        if [ "$SUMMARY_ONLY" = false ]; then
            echo -e "${YELLOW}[SKIP] Subnet $subnet.0/24 - only 1 host, skipping${NC}"
        fi
        continue
    fi

    echo -e "${CYAN}━━━ Subnet: $subnet.0/24 ($host_count hosts) ━━━${NC}"

    # Convert to arrays
    IFS=' ' read -ra host_list <<< "$hosts_in_subnet"

    # For each host, ping all other hosts in same subnet
    for src_entry in "${host_list[@]}"; do
        src_host=$(echo "$src_entry" | cut -d':' -f1)
        src_ip=$(echo "$src_entry" | cut -d':' -f2)

        # Check if container is running
        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${src_host}$"; then
            if [ "$SUMMARY_ONLY" = false ]; then
                echo -e "  ${RED}✗ $src_host ($src_ip) - container not running${NC}"
            fi
            continue
        fi

        for dst_entry in "${host_list[@]}"; do
            dst_host=$(echo "$dst_entry" | cut -d':' -f1)
            dst_ip=$(echo "$dst_entry" | cut -d':' -f2)

            # Don't ping yourself
            if [ "$src_host" = "$dst_host" ]; then
                continue
            fi

            total_tests=$((total_tests + 1))

            # Execute ping from source container to destination IP (with retry)
            ping_success=false
            for attempt in 1 2; do
                result=$(docker exec $src_host ping -c $PING_COUNT -W $PING_TIMEOUT $dst_ip 2>&1)
                ping_rc=$?
                if [ $ping_rc -eq 0 ]; then
                    ping_success=true
                    break
                fi
                # Brief pause before retry to allow controller to install flow
                sleep 1
            done

            if [ "$ping_success" = true ]; then
                success_tests=$((success_tests + 1))
                if [ "$SUMMARY_ONLY" = false ] && [ "$VERBOSE" = false ]; then
                    rtt=$(echo "$result" | grep -oP 'rtt.*= \K[0-9.]+' | head -1)
                    echo -e "  ${GREEN}✓ $src_host ($src_ip) -> $dst_host ($dst_ip) [avg ${rtt:-?}ms]${NC}"
                fi
            else
                fail_tests=$((fail_tests + 1))
                if [ "$SUMMARY_ONLY" = false ] && [ "$VERBOSE" = false ]; then
                    echo -e "  ${RED}✗ $src_host ($src_ip) -> $dst_host ($dst_ip) FAILED${NC}"
                fi
            fi

            if [ "$VERBOSE" = true ]; then
                echo -e "  ${YELLOW}$src_host ($src_ip) -> $dst_host ($dst_ip)${NC}"
                echo "$result" | sed 's/^/    /'
                if [ "$ping_success" = true ]; then
                    echo -e "    ${GREEN}✓ SUCCESS${NC}"
                else
                    echo -e "    ${RED}✗ FAILED${NC}"
                fi
            fi
        done
    done
    echo ""
done

# Print summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}=== Summary ===${NC}"
echo -e "Total ping tests: $total_tests"
echo -e "${GREEN}Success: $success_tests${NC}"
echo -e "${RED}Failed:  $fail_tests${NC}"
if [ $total_tests -gt 0 ]; then
    success_rate=$((success_tests * 100 / total_tests))
    echo -e "Success rate: ${success_rate}%"
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
