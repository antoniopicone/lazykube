#!/usr/bin/env bash

# LazyKube - Enhanced Cluster Configuration Script
# Supports multiple clusters, LazyLinux integration, and improved UX

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# LazyKube home
LAZYKUBE_HOME="${HOME}/.lazykube"
CLUSTERS_DIR="${LAZYKUBE_HOME}/clusters"
CURRENT_CLUSTER_FILE="${LAZYKUBE_HOME}/current-cluster"

# Source cluster manager
source "${SCRIPT_DIR}/cluster-manager.sh" 2>/dev/null || true

# Initialize LazyKube home
mkdir -p "${CLUSTERS_DIR}"

# Get current cluster or prompt for new one
get_or_create_cluster() {
    local current_cluster=$(cat "${CURRENT_CLUSTER_FILE}" 2>/dev/null || echo "")

    if [ -n "${current_cluster}" ] && [ -d "${CLUSTERS_DIR}/${current_cluster}" ]; then
        echo -e "${BLUE}Current cluster: ${current_cluster}${NC}"
        read -p "Configure this cluster or create a new one? [configure/new]: " choice
        choice=${choice:-configure}

        if [ "${choice}" = "new" ]; then
            create_new_cluster
        else
            CLUSTER_NAME="${current_cluster}"
            CLUSTER_PATH="${CLUSTERS_DIR}/${CLUSTER_NAME}"
        fi
    else
        create_new_cluster
    fi
}

create_new_cluster() {
    echo -e "${BLUE}Creating new cluster configuration${NC}"
    read -p "Enter cluster name (e.g., 'prod', 'dev', 'staging'): " CLUSTER_NAME

    # Validate cluster name
    if ! [[ "${CLUSTER_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid cluster name. Use only letters, numbers, dash, and underscore.${NC}"
        exit 1
    fi

    CLUSTER_PATH="${CLUSTERS_DIR}/${CLUSTER_NAME}"

    if [ -d "${CLUSTER_PATH}" ]; then
        echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists. Reconfiguring...${NC}"
    else
        mkdir -p "${CLUSTER_PATH}"
    fi

    echo "${CLUSTER_NAME}" > "${CURRENT_CLUSTER_FILE}"
    echo -e "${GREEN}✓ Using cluster: ${CLUSTER_NAME}${NC}"
}

# Read input with default value
read_with_default() {
    local prompt=$1
    local default=$2
    local varname=$3
    local value

    if [ -n "${default}" ]; then
        read -p "${prompt} [${default}]: " value
        value=${value:-$default}
    else
        read -p "${prompt}: " value
    fi

    eval "${varname}='${value}'"
}

# Check if LazyLinux is available
check_lazylinux() {
    if command -v lazylinux &> /dev/null; then
        return 0
    elif [ -f "${HOME}/lazylinux/lazylinux" ]; then
        LAZYLINUX_PATH="${HOME}/lazylinux/lazylinux"
        return 0
    elif [ -f "${HOME}/Developer/antoniopicone/lazylinux/lazylinux" ]; then
        LAZYLINUX_PATH="${HOME}/Developer/antoniopicone/lazylinux/lazylinux"
        return 0
    fi
    return 1
}

# LazyLinux integration
use_lazylinux() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           LazyLinux Integration - Automatic VM Setup         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! check_lazylinux; then
        echo -e "${YELLOW}LazyLinux not found.${NC}"
        echo "Install it from: https://github.com/antoniopicone/lazylinux"
        return 1
    fi

    echo -e "${GREEN}✓ LazyLinux found!${NC}"
    echo ""

    # Ask for VM configuration
    read_with_default "How many master nodes" "3" num_masters
    read_with_default "VM CPU cores per node" "2" vm_cpu
    read_with_default "VM RAM per node (MB)" "4096" vm_ram
    read_with_default "VM Disk size (GB)" "50" vm_disk
    read_with_default "Base IP address (will use .100, .102, .105, .106)" "192.168.105" base_ip

    echo ""
    echo -e "${BLUE}Creating VMs with LazyLinux...${NC}"

    # Create VMs (this is a placeholder - you'll need to adapt to actual LazyLinux commands)
    local lazylinux_cmd="${LAZYLINUX_PATH:-lazylinux}"

    echo -e "${YELLOW}Note: You'll need to create VMs manually with LazyLinux for now.${NC}"
    echo -e "${YELLOW}Run: ${lazylinux_cmd} create-vm --name k3s-master1 --cpu ${vm_cpu} --ram ${vm_ram} --disk ${vm_disk}${NC}"
    echo ""

    read -p "Have you created the VMs with LazyLinux? [y/N]: " vms_created

    if [[ ! "${vms_created}" =~ ^[Yy]$ ]]; then
        echo "Please create VMs first, then run this configuration again."
        return 1
    fi

    # Continue with manual IP entry
    return 0
}

# Manual VM configuration
manual_configuration() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Manual VM Configuration                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Choose cluster type
choose_cluster_type() {
    echo -e "${YELLOW}Choose your Kubernetes distribution:${NC}"
    echo ""
    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                    K3s vs RKE2 Comparison                              │${NC}"
    echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│ ${GREEN}K3s${BLUE}                           │ ${GREEN}RKE2${BLUE}                            │${NC}"
    echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│ ✓ Lightweight (~512MB RAM)    │ ✓ Security-focused (FIPS 140-2)     │${NC}"
    echo -e "${BLUE}│ ✓ Quick install (~2 min)      │ ✓ CIS Kubernetes Benchmark          │${NC}"
    echo -e "${BLUE}│ ✓ Perfect for dev/test        │ ✓ Government & enterprise compliant │${NC}"
    echo -e "${BLUE}│ ✓ IoT & Edge computing        │ ✓ Production-grade security         │${NC}"
    echo -e "${BLUE}│ ✓ Simple architecture         │ ✓ Hardened by default               │${NC}"
    echo -e "${BLUE}│                                │ ✓ Compliance certifications         │${NC}"
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    while true; do
        read_with_default "Select cluster type (k3s/rke2)" "${CLUSTER_TYPE:-k3s}" CLUSTER_TYPE
        CLUSTER_TYPE=$(echo "$CLUSTER_TYPE" | tr '[:upper:]' '[:lower:]')
        if [[ "$CLUSTER_TYPE" == "k3s" ]] || [[ "$CLUSTER_TYPE" == "rke2" ]]; then
            break
        fi
        echo -e "${RED}Invalid choice. Please enter 'k3s' or 'rke2'${NC}"
    done

    echo -e "${GREEN}✓ Selected: ${CLUSTER_TYPE}${NC}"
    echo ""
}

# Configure SSH authentication
configure_ssh_auth() {
    local node_name=$1
    local ip_addr=$2
    local default_user=$3

    read_with_default "Username for ${node_name}" "${default_user}" ssh_user

    echo ""
    echo -e "${YELLOW}SSH Authentication method:${NC}"
    echo "1) SSH Key (recommended)"
    echo "2) Password"
    read -p "Choose [1/2]: " auth_method

    case "${auth_method}" in
        1)
            read_with_default "Path to SSH private key" "${HOME}/.ssh/id_rsa" ssh_key
            if [ ! -f "${ssh_key}" ]; then
                echo -e "${RED}Error: SSH key not found at ${ssh_key}${NC}"
                exit 1
            fi
            SSH_AUTH_TYPE="key"
            SSH_KEY_PATH="${ssh_key}"
            SSH_PASSWORD=""
            ;;
        2)
            echo -n "Password for ${ssh_user}@${ip_addr}: "
            read -s ssh_password
            echo ""
            SSH_AUTH_TYPE="password"
            SSH_KEY_PATH=""
            SSH_PASSWORD="${ssh_password}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# Main configuration
main() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              LazyKube - Cluster Configuration                 ║${NC}"
    echo -e "${CYAN}║          K3s/RKE2 HA Cluster on Local VMs (Multipass)       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Get or create cluster
    get_or_create_cluster

    echo ""
    echo -e "${BLUE}Cluster configuration will be saved to: ${CLUSTER_PATH}${NC}"
    echo ""

    # Step 2: Choose VM creation method
    echo -e "${YELLOW}How do you want to set up the VMs?${NC}"
    echo "1) Use LazyLinux for automatic VM creation (recommended)"
    echo "2) Manual configuration (I already have VMs)"
    read -p "Choose [1/2]: " vm_method

    case "${vm_method}" in
        1)
            if ! use_lazylinux; then
                echo -e "${YELLOW}Falling back to manual configuration...${NC}"
                manual_configuration
            fi
            ;;
        2)
            manual_configuration
            ;;
        *)
            echo -e "${RED}Invalid choice, using manual configuration${NC}"
            manual_configuration
            ;;
    esac

    # Step 3: Choose cluster type
    choose_cluster_type

    # Step 4: Domain configuration
    read_with_default "Local domain" "${CLUSTER_NAME}.dev" DOMAIN

    # Step 5: HAProxy configuration
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    echo -e "${BLUE}        HAProxy (Load Balancer)${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    read_with_default "HAProxy IP address" "192.168.105.106" HAPROXY_IP

    local default_user="antonio"
    configure_ssh_auth "HAProxy" "${HAPROXY_IP}" "${default_user}"
    HAPROXY_USER="${ssh_user}"
    HAPROXY_AUTH_TYPE="${SSH_AUTH_TYPE}"
    HAPROXY_KEY_PATH="${SSH_KEY_PATH}"
    HAPROXY_PASSWORD="${SSH_PASSWORD}"

    # Step 6: Master nodes configuration
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    echo -e "${BLUE}        Master Nodes (Control Plane)${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"

    MASTER_IPS=()
    MASTER_USERS=()
    MASTER_AUTH_TYPES=()
    MASTER_KEY_PATHS=()
    MASTER_PASSWORDS=()

    for i in 1 2 3; do
        echo ""
        echo -e "${YELLOW}Master Node ${i}:${NC}"

        local default_ip="192.168.105.$((100 + i - 1))"
        if [ $i -eq 2 ]; then default_ip="192.168.105.102"; fi
        if [ $i -eq 3 ]; then default_ip="192.168.105.105"; fi

        read_with_default "IP address" "${default_ip}" master_ip
        MASTER_IPS+=("${master_ip}")

        configure_ssh_auth "Master ${i}" "${master_ip}" "${default_user}"
        MASTER_USERS+=("${ssh_user}")
        MASTER_AUTH_TYPES+=("${SSH_AUTH_TYPE}")
        MASTER_KEY_PATHS+=("${SSH_KEY_PATH}")
        MASTER_PASSWORDS+=("${SSH_PASSWORD}")
    done

    # Step 7: MetalLB IP range
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    echo -e "${BLUE}        MetalLB (LoadBalancer)${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    read_with_default "MetalLB IP range" "192.168.105.200-192.168.105.250" METALLB_RANGE

    # Save configuration to cluster directory
    save_configuration
    create_inventory
    update_group_vars
    create_ansible_cfg
    save_cluster_info

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                 ✓ Configuration Complete!                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Cluster: ${CLUSTER_NAME}${NC}"
    echo -e "${BLUE}Type: ${CLUSTER_TYPE}${NC}"
    echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
    echo -e "${BLUE}Config: ${CLUSTER_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. lazykube install          # Install the cluster"
    echo "  2. lazykube verify           # Verify installation"
    echo "  3. lazykube dashboard        # Access Traefik dashboard"
    echo ""
    echo -e "${YELLOW}Manage clusters:${NC}"
    echo "  lazykube cluster list        # List all clusters"
    echo "  lazykube cluster switch <name>  # Switch between clusters"
    echo ""
}

save_configuration() {
    local config_file="${CLUSTER_PATH}/.cluster-config"

    cat > "${config_file}" << EOF
# LazyKube Cluster Configuration
# Cluster: ${CLUSTER_NAME}

CLUSTER_NAME="${CLUSTER_NAME}"
CLUSTER_TYPE="${CLUSTER_TYPE}"
DOMAIN="${DOMAIN}"

# HAProxy
HAPROXY_IP="${HAPROXY_IP}"
HAPROXY_USER="${HAPROXY_USER}"
HAPROXY_AUTH_TYPE="${HAPROXY_AUTH_TYPE}"
HAPROXY_KEY_PATH="${HAPROXY_KEY_PATH}"
HAPROXY_PASSWORD="${HAPROXY_PASSWORD}"

# Master Nodes
MASTER1_IP="${MASTER_IPS[0]}"
MASTER1_USER="${MASTER_USERS[0]}"
MASTER1_AUTH_TYPE="${MASTER_AUTH_TYPES[0]}"
MASTER1_KEY_PATH="${MASTER_KEY_PATHS[0]}"
MASTER1_PASSWORD="${MASTER_PASSWORDS[0]}"

MASTER2_IP="${MASTER_IPS[1]}"
MASTER2_USER="${MASTER_USERS[1]}"
MASTER2_AUTH_TYPE="${MASTER_AUTH_TYPES[1]}"
MASTER2_KEY_PATH="${MASTER_KEY_PATHS[1]}"
MASTER2_PASSWORD="${MASTER_PASSWORDS[1]}"

MASTER3_IP="${MASTER_IPS[2]}"
MASTER3_USER="${MASTER_USERS[2]}"
MASTER3_AUTH_TYPE="${MASTER_AUTH_TYPES[2]}"
MASTER3_KEY_PATH="${MASTER_KEY_PATHS[2]}"
MASTER3_PASSWORD="${MASTER_PASSWORDS[2]}"

# MetalLB
METALLB_RANGE="${METALLB_RANGE}"
EOF

    chmod 600 "${config_file}"
}

create_inventory() {
    local inventory_file="${CLUSTER_PATH}/hosts.yml"

    cat > "${inventory_file}" << EOF
---
all:
  children:
    haproxy:
      hosts:
        haproxy1:
          ansible_host: ${HAPROXY_IP}
          ansible_user: ${HAPROXY_USER}
EOF

    # Add HAProxy auth
    if [ "${HAPROXY_AUTH_TYPE}" = "key" ]; then
        echo "          ansible_ssh_private_key_file: ${HAPROXY_KEY_PATH}" >> "${inventory_file}"
    else
        echo "          ansible_ssh_pass: ${HAPROXY_PASSWORD}" >> "${inventory_file}"
        echo "          ansible_become_pass: ${HAPROXY_PASSWORD}" >> "${inventory_file}"
    fi

    cat >> "${inventory_file}" << EOF

    k3s_masters:
      hosts:
        master1:
          ansible_host: ${MASTER_IPS[0]}
          ansible_user: ${MASTER_USERS[0]}
EOF

    if [ "${MASTER_AUTH_TYPES[0]}" = "key" ]; then
        echo "          ansible_ssh_private_key_file: ${MASTER_KEY_PATHS[0]}" >> "${inventory_file}"
    else
        echo "          ansible_ssh_pass: ${MASTER_PASSWORDS[0]}" >> "${inventory_file}"
        echo "          ansible_become_pass: ${MASTER_PASSWORDS[0]}" >> "${inventory_file}"
    fi

    cat >> "${inventory_file}" << EOF
          is_first_master: true

        master2:
          ansible_host: ${MASTER_IPS[1]}
          ansible_user: ${MASTER_USERS[1]}
EOF

    if [ "${MASTER_AUTH_TYPES[1]}" = "key" ]; then
        echo "          ansible_ssh_private_key_file: ${MASTER_KEY_PATHS[1]}" >> "${inventory_file}"
    else
        echo "          ansible_ssh_pass: ${MASTER_PASSWORDS[1]}" >> "${inventory_file}"
        echo "          ansible_become_pass: ${MASTER_PASSWORDS[1]}" >> "${inventory_file}"
    fi

    cat >> "${inventory_file}" << EOF
          is_first_master: false

        master3:
          ansible_host: ${MASTER_IPS[2]}
          ansible_user: ${MASTER_USERS[2]}
EOF

    if [ "${MASTER_AUTH_TYPES[2]}" = "key" ]; then
        echo "          ansible_ssh_private_key_file: ${MASTER_KEY_PATHS[2]}" >> "${inventory_file}"
    else
        echo "          ansible_ssh_pass: ${MASTER_PASSWORDS[2]}" >> "${inventory_file}"
        echo "          ansible_become_pass: ${MASTER_PASSWORDS[2]}" >> "${inventory_file}"
    fi

    cat >> "${inventory_file}" << EOF
          is_first_master: false
EOF

    echo -e "${GREEN}✓ Created inventory: ${inventory_file}${NC}"
}

update_group_vars() {
    local group_vars_file="${CLUSTER_PATH}/all.yml"

    cp "${PROJECT_ROOT}/group_vars/all.yml" "${group_vars_file}"

    # Update with cluster-specific values
    sed -i.bak "s/^cluster_type:.*/cluster_type: \"${CLUSTER_TYPE}\"/" "${group_vars_file}"
    sed -i.bak "s/^haproxy_ip:.*/haproxy_ip: \"${HAPROXY_IP}\"/" "${group_vars_file}"
    sed -i.bak "s/^domain:.*/domain: \"${DOMAIN}\"/" "${group_vars_file}"
    sed -i.bak "s/^cluster_name:.*/cluster_name: \"${DOMAIN}\"/" "${group_vars_file}"
    sed -i.bak "s|^metallb_ip_range:.*|metallb_ip_range: \"${METALLB_RANGE}\"|" "${group_vars_file}"

    # Update master IPs
    sed -i.bak "s/- \"192.168.105.100\"/- \"${MASTER_IPS[0]}\"/" "${group_vars_file}"
    sed -i.bak "s/- \"192.168.105.102\"/- \"${MASTER_IPS[1]}\"/" "${group_vars_file}"
    sed -i.bak "s/- \"192.168.105.105\"/- \"${MASTER_IPS[2]}\"/" "${group_vars_file}"
    sed -i.bak "s/- \"192.168.105.106\"/- \"${HAPROXY_IP}\"/" "${group_vars_file}"

    rm -f "${group_vars_file}.bak"

    echo -e "${GREEN}✓ Updated group vars: ${group_vars_file}${NC}"
}

create_ansible_cfg() {
    local ansible_cfg="${CLUSTER_PATH}/ansible.cfg"

    cat > "${ansible_cfg}" << EOF
[defaults]
inventory = ${CLUSTER_PATH}/hosts.yml
host_key_checking = False
timeout = 30
stdout_callback = yaml
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_${CLUSTER_NAME}
fact_caching_timeout = 3600
EOF

    # Add sshpass settings if any node uses password auth
    local needs_sshpass=false
    if [ "${HAPROXY_AUTH_TYPE}" = "password" ]; then needs_sshpass=true; fi
    for auth_type in "${MASTER_AUTH_TYPES[@]}"; do
        if [ "${auth_type}" = "password" ]; then needs_sshpass=true; fi
    done

    if [ "${needs_sshpass}" = true ]; then
        cat >> "${ansible_cfg}" << EOF

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False
EOF
    fi

    echo -e "${GREEN}✓ Created ansible.cfg: ${ansible_cfg}${NC}"
}

save_cluster_info() {
    local info_file="${CLUSTER_PATH}/cluster-info.txt"

    cat > "${info_file}" << EOF
Type: ${CLUSTER_TYPE}
Domain: ${DOMAIN}
HAProxy: ${HAPROXY_IP}
Masters: ${MASTER_IPS[0]}, ${MASTER_IPS[1]}, ${MASTER_IPS[2]}
MetalLB: ${METALLB_RANGE}
EOF
}

# Run main
main
