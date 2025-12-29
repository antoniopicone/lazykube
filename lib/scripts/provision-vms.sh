#!/usr/bin/env bash

# LazyKube VM Provisioning Script
# Creates VMs using lazylinux and configures them for K3s HA cluster

set -e

# Load helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

# ============================================
# VM Provisioning Functions
# ============================================

# Provision cluster VMs using lazylinux
provision_cluster_vms() {
    local cluster_name=$1
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Provisioning VMs for cluster: ${cluster_name}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local lazylinux_bin=$(get_lazylinux_bin)

    # Check if lazylinux is available
    # If it's just a command name (like "vm"), check if it's in PATH
    # If it's a path, check if it's executable
    if [[ "$lazylinux_bin" == *"/"* ]]; then
        # It's a path, check if executable
        if [ ! -x "$lazylinux_bin" ]; then
            echo -e "${RED}Error: lazylinux not found at $lazylinux_bin${NC}"
            exit 1
        fi
    else
        # It's a command name, check if it's in PATH
        if ! command -v "$lazylinux_bin" >/dev/null 2>&1; then
            echo -e "${RED}Error: $lazylinux_bin command not found in PATH${NC}"
            exit 1
        fi
    fi

    # VM configuration
    local vm_prefix="${cluster_name}"
    local base_ip="192.168.105"
    local ip_offset=50

    echo -e "${YELLOW}Creating 4 VMs:${NC}"
    echo "  - 3 K3s master nodes"
    echo "  - 1 HAProxy load balancer"
    echo ""

    # Create VMs using lazylinux
    # Note: Adjust these commands based on actual lazylinux API

    echo -e "${BLUE}Creating HAProxy VM...${NC}"
    local haproxy_name="${vm_prefix}-haproxy"
    if "$lazylinux_bin" list | grep -q "$haproxy_name"; then
        echo -e "${YELLOW}VM $haproxy_name already exists, skipping...${NC}"
    else
        "$lazylinux_bin" create \
            --name "$haproxy_name" \
            --memory 2G \
            --cpus 2 \
            --disk 20G || {
                echo -e "${RED}Error: Failed to create VM $haproxy_name${NC}"
                exit 1
            }
    fi

    echo -e "${BLUE}Creating Master 1 VM...${NC}"
    local master1_name="${vm_prefix}-master1"
    if "$lazylinux_bin" list | grep -q "$master1_name"; then
        echo -e "${YELLOW}VM $master1_name already exists, skipping...${NC}"
    else
        "$lazylinux_bin" create \
            --name "$master1_name" \
            --memory 4G \
            --cpus 2 \
            --disk 40G || {
                echo -e "${RED}Error: Failed to create VM $master1_name${NC}"
                exit 1
            }
    fi

    echo -e "${BLUE}Creating Master 2 VM...${NC}"
    local master2_name="${vm_prefix}-master2"
    if "$lazylinux_bin" list | grep -q "$master2_name"; then
        echo -e "${YELLOW}VM $master2_name already exists, skipping...${NC}"
    else
        "$lazylinux_bin" create \
            --name "$master2_name" \
            --memory 4G \
            --cpus 2 \
            --disk 40G || {
                echo -e "${RED}Error: Failed to create VM $master2_name${NC}"
                exit 1
            }
    fi

    echo -e "${BLUE}Creating Master 3 VM...${NC}"
    local master3_name="${vm_prefix}-master3"
    if "$lazylinux_bin" list | grep -q "$master3_name"; then
        echo -e "${YELLOW}VM $master3_name already exists, skipping...${NC}"
    else
        "$lazylinux_bin" create \
            --name "$master3_name" \
            --memory 4G \
            --cpus 2 \
            --disk 40G || {
                echo -e "${RED}Error: Failed to create VM $master3_name${NC}"
                exit 1
            }
    fi

    echo ""
    echo -e "${BLUE}Waiting for VMs to boot...${NC}"
    sleep 10

    # Get VM IPs
    echo -e "${BLUE}Retrieving VM IP addresses...${NC}"
    local haproxy_ip=$(get_vm_ip_with_retry "$haproxy_name")
    local master1_ip=$(get_vm_ip_with_retry "$master1_name")
    local master2_ip=$(get_vm_ip_with_retry "$master2_name")
    local master3_ip=$(get_vm_ip_with_retry "$master3_name")

    # Fallback to static IPs if lazylinux doesn't provide them
    if [ -z "$haproxy_ip" ]; then
        haproxy_ip="${base_ip}.$((ip_offset))"
        echo -e "${YELLOW}Using fallback IP for HAProxy: $haproxy_ip${NC}"
    fi
    if [ -z "$master1_ip" ]; then
        master1_ip="${base_ip}.$((ip_offset + 1))"
        echo -e "${YELLOW}Using fallback IP for Master 1: $master1_ip${NC}"
    fi
    if [ -z "$master2_ip" ]; then
        master2_ip="${base_ip}.$((ip_offset + 2))"
        echo -e "${YELLOW}Using fallback IP for Master 2: $master2_ip${NC}"
    fi
    if [ -z "$master3_ip" ]; then
        master3_ip="${base_ip}.$((ip_offset + 3))"
        echo -e "${YELLOW}Using fallback IP for Master 3: $master3_ip${NC}"
    fi

    echo ""
    echo -e "${GREEN}VMs created successfully:${NC}"
    echo "  HAProxy:  $haproxy_name ($haproxy_ip)"
    echo "  Master 1: $master1_name ($master1_ip)"
    echo "  Master 2: $master2_name ($master2_ip)"
    echo "  Master 3: $master3_name ($master3_ip)"
    echo ""

    # Save VM information
    cat > "${cluster_dir}/vms/vm_info.txt" << EOF
# VM Information for cluster: $cluster_name
HAPROXY_NAME=$haproxy_name
HAPROXY_IP=$haproxy_ip
MASTER1_NAME=$master1_name
MASTER1_IP=$master1_ip
MASTER2_NAME=$master2_name
MASTER2_IP=$master2_ip
MASTER3_NAME=$master3_name
MASTER3_IP=$master3_ip
EOF

    # Generate Ansible inventory and group_vars
    generate_cluster_config "$cluster_name" "$haproxy_ip" "$master1_ip" "$master2_ip" "$master3_ip"

    echo ""
    echo -e "${GREEN}✓ VM provisioning completed!${NC}"
    echo ""
}

# Get VM IP with retry logic
get_vm_ip_with_retry() {
    local vm_name=$1
    local max_retries=5
    local retry=0
    local ip=""

    while [ $retry -lt $max_retries ]; do
        ip=$(get_vm_ip "$vm_name" 2>/dev/null | tr -d '\n\r' | xargs || echo "")
        if [ -n "$ip" ] && [ "$ip" != "null" ]; then
            echo "$ip"
            return 0
        fi
        retry=$((retry + 1))
        sleep 2
    done

    echo ""
}

# Generate cluster configuration files
generate_cluster_config() {
    local cluster_name=$1
    local haproxy_ip=$2
    local master1_ip=$3
    local master2_ip=$4
    local master3_ip=$5
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"
    local domain=$(generate_domain "$cluster_name")

    # SSH credentials from lazylinux VMs (user01 with password auth)
    local ssh_user="user01"
    local vm_prefix="${cluster_name}"

    # Get VM passwords from lazylinux output (sanitize to remove newlines/whitespace)
    local lazylinux_bin=$(get_lazylinux_bin)
    local haproxy_password=$("$lazylinux_bin" list | grep "${vm_prefix}-haproxy" | awk '{print $NF}' | tr -d '\n\r' | xargs)
    local master1_password=$("$lazylinux_bin" list | grep "${vm_prefix}-master1" | awk '{print $NF}' | tr -d '\n\r' | xargs)
    local master2_password=$("$lazylinux_bin" list | grep "${vm_prefix}-master2" | awk '{print $NF}' | tr -d '\n\r' | xargs)
    local master3_password=$("$lazylinux_bin" list | grep "${vm_prefix}-master3" | awk '{print $NF}' | tr -d '\n\r' | xargs)

    echo -e "${YELLOW}Generating cluster configuration files...${NC}"
    echo -e "${BLUE}Retrieved VM credentials from lazylinux${NC}"

    # Create cluster-config file
    cat > "${cluster_dir}/cluster-config" << EOF
# K3s HA Cluster Configuration
# Generated by lazylinux provisioning
# Cluster: $cluster_name

# Master 1
MASTER1_IP="$master1_ip"
MASTER1_USER="$ssh_user"
MASTER1_PASSWORD="$master1_password"

# Master 2
MASTER2_IP="$master2_ip"
MASTER2_USER="$ssh_user"
MASTER2_PASSWORD="$master2_password"

# Master 3
MASTER3_IP="$master3_ip"
MASTER3_USER="$ssh_user"
MASTER3_PASSWORD="$master3_password"

# HAProxy
HAPROXY_IP="$haproxy_ip"
HAPROXY_USER="$ssh_user"
HAPROXY_PASSWORD="$haproxy_password"

# Cluster config
DOMAIN="$domain"
TIMEZONE="Europe/Rome"
EOF

    # Create Ansible inventory
    cat > "${cluster_dir}/inventory/hosts.yml" << EOF
---
# Ansible Inventory - Auto-generated by lazykube
# Cluster: $cluster_name

all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_connection: ssh
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    domain: "$domain"
    timezone: "Europe/Rome"

  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
            master1:
              ansible_host: $master1_ip
              ansible_user: $ssh_user
              ansible_password: $master1_password
              k3s_node_name: k3s-master1
              is_first_master: true
            master2:
              ansible_host: $master2_ip
              ansible_user: $ssh_user
              ansible_password: $master2_password
              k3s_node_name: k3s-master2
              is_first_master: false
            master3:
              ansible_host: $master3_ip
              ansible_user: $ssh_user
              ansible_password: $master3_password
              k3s_node_name: k3s-master3
              is_first_master: false

    haproxy:
      hosts:
        haproxy1:
          ansible_host: $haproxy_ip
          ansible_user: $ssh_user
          ansible_password: $haproxy_password
EOF

    # Copy group_vars template
    if [ -n "$LAZYKUBE_SHARE_DIR" ] && [ -f "$LAZYKUBE_SHARE_DIR/templates/all.yml.template" ]; then
        cp "$LAZYKUBE_SHARE_DIR/templates/all.yml.template" "${cluster_dir}/group_vars/all.yml"

        # Update group_vars with IPs and domain
        sed -i.bak "s/^haproxy_ip:.*/haproxy_ip: \"$haproxy_ip\"/" "${cluster_dir}/group_vars/all.yml"
        sed -i.bak "s/^domain:.*/domain: \"$domain\"/" "${cluster_dir}/group_vars/all.yml"

        # Update master_ips array - use awk for macOS compatibility
        awk -v m1="$master1_ip" -v m2="$master2_ip" -v m3="$master3_ip" -v hp="$haproxy_ip" '
            /^master_ips:/ {
                print $0
                print "  - \"" m1 "\""
                print "  - \"" m2 "\""
                print "  - \"" m3 "\""
                print "  - \"" hp "\""
                in_master_ips = 1
                next
            }
            in_master_ips && /^[^ ]/ {
                in_master_ips = 0
            }
            !in_master_ips || !/^  -/ {
                print $0
            }
        ' "${cluster_dir}/group_vars/all.yml" > "${cluster_dir}/group_vars/all.yml.tmp" && \
        mv "${cluster_dir}/group_vars/all.yml.tmp" "${cluster_dir}/group_vars/all.yml"

        rm -f "${cluster_dir}/group_vars/all.yml.bak"
    fi

    # Save cluster metadata
    save_cluster_metadata "$cluster_name" "$domain" "$haproxy_ip" "$master1_ip" "$master2_ip" "$master3_ip"

    echo -e "${GREEN}✓ Configuration files generated${NC}"
}

# Destroy cluster VMs
destroy_cluster_vms() {
    local cluster_name=$1
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"
    local vm_info="${cluster_dir}/vms/vm_info.txt"

    if [ ! -f "$vm_info" ]; then
        echo -e "${YELLOW}No VM information found for cluster $cluster_name${NC}"
        return
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Destroying VMs for cluster: ${cluster_name}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Load VM information
    source "$vm_info"

    local lazylinux_bin=$(get_lazylinux_bin)

    # Delete VMs
    for vm_name in "$HAPROXY_NAME" "$MASTER1_NAME" "$MASTER2_NAME" "$MASTER3_NAME"; do
        if [ -n "$vm_name" ]; then
            echo -e "${BLUE}Deleting VM: $vm_name${NC}"
            "$lazylinux_bin" delete "$vm_name" --force 2>/dev/null || {
                echo -e "${YELLOW}Could not delete VM $vm_name (may not exist)${NC}"
            }
        fi
    done

    echo ""
    echo -e "${GREEN}✓ VMs destroyed${NC}"
    echo ""
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # This script is being executed directly
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <provision|destroy> <cluster_name>"
        exit 1
    fi

    ACTION=$1
    CLUSTER_NAME=$2

    case "$ACTION" in
        provision)
            provision_cluster_vms "$CLUSTER_NAME"
            ;;
        destroy)
            destroy_cluster_vms "$CLUSTER_NAME"
            ;;
        *)
            echo "Unknown action: $ACTION"
            echo "Usage: $0 <provision|destroy> <cluster_name>"
            exit 1
            ;;
    esac
fi
