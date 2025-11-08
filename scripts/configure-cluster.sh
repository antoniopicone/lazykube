#!/bin/bash
set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_FILE=".cluster-config"
INVENTORY_FILE="inventories/hosts.yml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}K3s HA Cluster Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to read input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local varname="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
    fi

    eval "$varname='$value'"
}

# Function to read password (optional)
read_password() {
    local prompt="$1"
    local varname="$2"

    read -s -p "$prompt (leave empty if using SSH key): " password
    echo ""
    eval "$varname='$password'"
}

# Function to validate IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        echo -e "${RED}Invalid IP: $ip${NC}"
        return 1
    fi
}

# Load existing configuration if available
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Existing configuration found.${NC}"
    echo -n "Do you want to reconfigure? [y/N]: "
    read reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Existing configuration kept.${NC}"
        exit 0
    fi
    source "$CONFIG_FILE"
fi

echo -e "${YELLOW}Configure the 4 cluster VMs:${NC}"
echo ""

# Master 1
echo -e "${BLUE}--- Master 1 (first control-plane) ---${NC}"
while true; do
    read_with_default "Master 1 IP" "${MASTER1_IP:-192.168.105.46}" MASTER1_IP
    validate_ip "$MASTER1_IP" && break
done
read_with_default "Master 1 SSH username" "${MASTER1_USER:-admin}" MASTER1_USER
read_password "Master 1 SSH password" MASTER1_PASSWORD
read_with_default "Master 1 SSH key path" "${MASTER1_SSH_KEY:-}" MASTER1_SSH_KEY
echo ""

# Master 2
echo -e "${BLUE}--- Master 2 ---${NC}"
while true; do
    read_with_default "Master 2 IP" "${MASTER2_IP:-192.168.105.47}" MASTER2_IP
    validate_ip "$MASTER2_IP" && break
done
read_with_default "Master 2 SSH username" "${MASTER2_USER:-$MASTER1_USER}" MASTER2_USER
read_password "Master 2 SSH password" MASTER2_PASSWORD
read_with_default "Master 2 SSH key path" "${MASTER2_SSH_KEY:-$MASTER1_SSH_KEY}" MASTER2_SSH_KEY
echo ""

# Master 3
echo -e "${BLUE}--- Master 3 ---${NC}"
while true; do
    read_with_default "Master 3 IP" "${MASTER3_IP:-192.168.105.48}" MASTER3_IP
    validate_ip "$MASTER3_IP" && break
done
read_with_default "Master 3 SSH username" "${MASTER3_USER:-$MASTER1_USER}" MASTER3_USER
read_password "Master 3 SSH password" MASTER3_PASSWORD
read_with_default "Master 3 SSH key path" "${MASTER3_SSH_KEY:-$MASTER1_SSH_KEY}" MASTER3_SSH_KEY
echo ""

# HAProxy
echo -e "${BLUE}--- HAProxy Load Balancer ---${NC}"
while true; do
    read_with_default "HAProxy IP" "${HAPROXY_IP:-192.168.105.49}" HAPROXY_IP
    validate_ip "$HAPROXY_IP" && break
done
read_with_default "HAProxy SSH username" "${HAPROXY_USER:-$MASTER1_USER}" HAPROXY_USER
read_password "HAProxy SSH password" HAPROXY_PASSWORD
read_with_default "HAProxy SSH key path" "${HAPROXY_SSH_KEY:-$MASTER1_SSH_KEY}" HAPROXY_SSH_KEY
echo ""

# Additional configurations
echo -e "${BLUE}--- Cluster Configuration ---${NC}"

# Cluster type selection with comparison
echo -e "${YELLOW}Choose your Kubernetes distribution:${NC}"
echo ""
echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│                    K3s vs RKE2 Comparison                              │${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│                                                                        │${NC}"
echo -e "${BLUE}│  ${GREEN}K3s${NC} - Lightweight Kubernetes                                       ${BLUE}│${NC}"
echo -e "${BLUE}│    ${GREEN}✓${NC} Pros:                                                           ${BLUE}│${NC}"
echo -e "${BLUE}│      • Minimal resource usage (~512MB RAM per node)                   ${BLUE}│${NC}"
echo -e "${BLUE}│      • Quick installation (<2 minutes)                                 ${BLUE}│${NC}"
echo -e "${BLUE}│      • Single binary (~50MB)                                           ${BLUE}│${NC}"
echo -e "${BLUE}│      • Perfect for development, edge, IoT                              ${BLUE}│${NC}"
echo -e "${BLUE}│      • SQLite or etcd backend options                                  ${BLUE}│${NC}"
echo -e "${BLUE}│    ${RED}✗${NC} Cons:                                                           ${BLUE}│${NC}"
echo -e "${BLUE}│      • Less focus on compliance certifications                         ${BLUE}│${NC}"
echo -e "${BLUE}│      • Simplified architecture (may not suit all production needs)     ${BLUE}│${NC}"
echo -e "${BLUE}│                                                                        │${NC}"
echo -e "${BLUE}│  ${GREEN}RKE2${NC} - Security-Focused Kubernetes                                  ${BLUE}│${NC}"
echo -e "${BLUE}│    ${GREEN}✓${NC} Pros:                                                           ${BLUE}│${NC}"
echo -e "${BLUE}│      • FIPS 140-2 compliant (federal/government use)                   ${BLUE}│${NC}"
echo -e "${BLUE}│      • CIS Kubernetes Benchmark compliance by default                  ${BLUE}│${NC}"
echo -e "${BLUE}│      • SELinux support out-of-the-box                                  ${BLUE}│${NC}"
echo -e "${BLUE}│      • Better for regulated industries (finance, healthcare)           ${BLUE}│${NC}"
echo -e "${BLUE}│      • Production-grade security hardening                             ${BLUE}│${NC}"
echo -e "${BLUE}│    ${RED}✗${NC} Cons:                                                           ${BLUE}│${NC}"
echo -e "${BLUE}│      • Higher resource usage (~1GB+ RAM per node)                      ${BLUE}│${NC}"
echo -e "${BLUE}│      • Longer installation time (5-10 minutes)                         ${BLUE}│${NC}"
echo -e "${BLUE}│      • Larger footprint (~150MB)                                       ${BLUE}│${NC}"
echo -e "${BLUE}│                                                                        │${NC}"
echo -e "${BLUE}│  ${YELLOW}Use Cases:${NC}                                                         ${BLUE}│${NC}"
echo -e "${BLUE}│    • K3s:  Dev/Test, Edge Computing, IoT, Resource-constrained        ${BLUE}│${NC}"
echo -e "${BLUE}│    • RKE2: Production, Compliance-required, High-security environments ${BLUE}│${NC}"
echo -e "${BLUE}│                                                                        │${NC}"
echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Read cluster type with validation
while true; do
    read_with_default "Select cluster type (k3s/rke2)" "${CLUSTER_TYPE:-k3s}" CLUSTER_TYPE
    CLUSTER_TYPE=$(echo "$CLUSTER_TYPE" | tr '[:upper:]' '[:lower:]')
    if [[ "$CLUSTER_TYPE" == "k3s" ]] || [[ "$CLUSTER_TYPE" == "rke2" ]]; then
        break
    else
        echo -e "${RED}Invalid cluster type. Please enter 'k3s' or 'rke2'${NC}"
    fi
done

echo -e "${GREEN}✓ Selected: $CLUSTER_TYPE${NC}"
echo ""

read_with_default "Cluster domain" "${DOMAIN:-k3cluster.local}" DOMAIN
read_with_default "Timezone" "${TIMEZONE:-Europe/Rome}" TIMEZONE
echo ""

# Save configuration
echo -e "${YELLOW}Saving configuration...${NC}"
cat > "$CONFIG_FILE" << EOF
# K3s HA Cluster Configuration
# Generated by configure-cluster.sh

# Master 1
MASTER1_IP="$MASTER1_IP"
MASTER1_USER="$MASTER1_USER"
MASTER1_PASSWORD="$MASTER1_PASSWORD"
MASTER1_SSH_KEY="$MASTER1_SSH_KEY"

# Master 2
MASTER2_IP="$MASTER2_IP"
MASTER2_USER="$MASTER2_USER"
MASTER2_PASSWORD="$MASTER2_PASSWORD"
MASTER2_SSH_KEY="$MASTER2_SSH_KEY"

# Master 3
MASTER3_IP="$MASTER3_IP"
MASTER3_USER="$MASTER3_USER"
MASTER3_PASSWORD="$MASTER3_PASSWORD"
MASTER3_SSH_KEY="$MASTER3_SSH_KEY"

# HAProxy
HAPROXY_IP="$HAPROXY_IP"
HAPROXY_USER="$HAPROXY_USER"
HAPROXY_PASSWORD="$HAPROXY_PASSWORD"
HAPROXY_SSH_KEY="$HAPROXY_SSH_KEY"

# Cluster config
CLUSTER_TYPE="$CLUSTER_TYPE"
DOMAIN="$DOMAIN"
TIMEZONE="$TIMEZONE"
EOF

echo -e "${GREEN}✓ Configuration saved to $CONFIG_FILE${NC}"
echo ""

# Generate Ansible inventory
echo -e "${YELLOW}Generating Ansible inventory...${NC}"

# Create directory if it doesn't exist
mkdir -p inventories

cat > "$INVENTORY_FILE" << EOF
---
# Ansible Inventory - Auto-generated by configure-cluster.sh
# DO NOT EDIT MANUALLY - Run './lazykube configure' to reconfigure

all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    cluster_type: "$CLUSTER_TYPE"
    domain: "$DOMAIN"
    timezone: "$TIMEZONE"

  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
            master1:
              ansible_host: $MASTER1_IP
              ansible_user: $MASTER1_USER
EOF

# Add password or SSH key for master1
if [ -n "$MASTER1_PASSWORD" ]; then
    echo "              ansible_password: $MASTER1_PASSWORD" >> "$INVENTORY_FILE"
fi
if [ -n "$MASTER1_SSH_KEY" ]; then
    echo "              ansible_ssh_private_key_file: $MASTER1_SSH_KEY" >> "$INVENTORY_FILE"
fi

cat >> "$INVENTORY_FILE" << EOF
              k3s_node_name: k3s-master1
              is_first_master: true
            master2:
              ansible_host: $MASTER2_IP
              ansible_user: $MASTER2_USER
EOF

# Add password or SSH key for master2
if [ -n "$MASTER2_PASSWORD" ]; then
    echo "              ansible_password: $MASTER2_PASSWORD" >> "$INVENTORY_FILE"
fi
if [ -n "$MASTER2_SSH_KEY" ]; then
    echo "              ansible_ssh_private_key_file: $MASTER2_SSH_KEY" >> "$INVENTORY_FILE"
fi

cat >> "$INVENTORY_FILE" << EOF
              k3s_node_name: k3s-master2
              is_first_master: false
            master3:
              ansible_host: $MASTER3_IP
              ansible_user: $MASTER3_USER
EOF

# Add password or SSH key for master3
if [ -n "$MASTER3_PASSWORD" ]; then
    echo "              ansible_password: $MASTER3_PASSWORD" >> "$INVENTORY_FILE"
fi
if [ -n "$MASTER3_SSH_KEY" ]; then
    echo "              ansible_ssh_private_key_file: $MASTER3_SSH_KEY" >> "$INVENTORY_FILE"
fi

cat >> "$INVENTORY_FILE" << EOF
              k3s_node_name: k3s-master3
              is_first_master: false

    haproxy:
      hosts:
        haproxy1:
          ansible_host: $HAPROXY_IP
          ansible_user: $HAPROXY_USER
EOF

# Add password or SSH key for haproxy
if [ -n "$HAPROXY_PASSWORD" ]; then
    echo "          ansible_password: $HAPROXY_PASSWORD" >> "$INVENTORY_FILE"
fi
if [ -n "$HAPROXY_SSH_KEY" ]; then
    echo "          ansible_ssh_private_key_file: $HAPROXY_SSH_KEY" >> "$INVENTORY_FILE"
fi

echo -e "${GREEN}✓ Inventory generated at $INVENTORY_FILE${NC}"
echo ""

# Update group_vars/all.yml with IPs
echo -e "${YELLOW}Updating group_vars/all.yml...${NC}"

GROUP_VARS="group_vars/all.yml"
if [ -f "$GROUP_VARS" ]; then
    # Backup
    cp "$GROUP_VARS" "$GROUP_VARS.backup-$(date +%Y%m%d-%H%M%S)"

    # Update haproxy_ip
    sed -i.tmp "s/^haproxy_ip:.*/haproxy_ip: \"$HAPROXY_IP\"/" "$GROUP_VARS"

    # Update master_ips
    sed -i.tmp "/^master_ips:/,/^[^ ]/ {
        /^  -/ d
        /^master_ips:/ a\\
  - \"$MASTER1_IP\"\\
  - \"$MASTER2_IP\"\\
  - \"$MASTER3_IP\"\\
  - \"$HAPROXY_IP\"
    }" "$GROUP_VARS"

    # Update domain
    sed -i.tmp "s/^domain:.*/domain: \"$DOMAIN\"/" "$GROUP_VARS"

    # Update cluster_name to match domain
    sed -i.tmp "s/^cluster_name:.*/cluster_name: \"$DOMAIN\"/" "$GROUP_VARS"

    # Update cluster_type
    sed -i.tmp "s/^cluster_type:.*/cluster_type: \"$CLUSTER_TYPE\"/" "$GROUP_VARS"

    rm -f "$GROUP_VARS.tmp"

    echo -e "${GREEN}✓ group_vars/all.yml updated${NC}"
else
    echo -e "${YELLOW}⚠️  group_vars/all.yml not found, skipped${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Configuration completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  Cluster Type: $CLUSTER_TYPE"
echo "  Master 1: $MASTER1_IP (user: $MASTER1_USER)"
echo "  Master 2: $MASTER2_IP (user: $MASTER2_USER)"
echo "  Master 3: $MASTER3_IP (user: $MASTER3_USER)"
echo "  HAProxy:  $HAPROXY_IP (user: $HAPROXY_USER)"
echo "  Domain:   $DOMAIN"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. ./lazykube check    # Verify SSH connectivity"
echo "  2. ./lazykube install  # Install $CLUSTER_TYPE HA cluster"
echo ""
