#!/usr/bin/env bash

# LazyKube Helper Functions
# Common functions for dependency management, cluster state, and VM operations

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directories
LAZYKUBE_CONFIG_DIR="${LAZYKUBE_CONFIG_DIR:-${HOME}/.lazykube}"
CLUSTERS_DIR="${LAZYKUBE_CONFIG_DIR}/clusters"
LAZYLINUX_DIR="${LAZYKUBE_CONFIG_DIR}/lazylinux"

# ============================================
# Dependency Management Functions
# ============================================

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}Error: Homebrew is not installed!${NC}"
        echo "Install Homebrew first: https://brew.sh"
        exit 1
    fi
}

# Check and install Ansible
check_install_ansible() {
    if command -v ansible >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ansible is already installed${NC}"
        return 0
    fi

    echo -e "${YELLOW}Ansible is not installed${NC}"
    read -p "Install Ansible via Homebrew? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        check_homebrew
        echo -e "${BLUE}Installing Ansible via Homebrew...${NC}"
        brew install ansible
        echo -e "${GREEN}✓ Ansible installed successfully!${NC}"
    else
        echo -e "${RED}Ansible is required to manage clusters.${NC}"
        exit 1
    fi
}

# Check and install kubectl
check_install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        echo -e "${GREEN}✓ kubectl is already installed${NC}"
        return 0
    fi

    echo -e "${YELLOW}kubectl is not installed${NC}"
    read -p "Install kubectl via Homebrew? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        check_homebrew
        echo -e "${BLUE}Installing kubectl via Homebrew...${NC}"
        brew install kubectl
        echo -e "${GREEN}✓ kubectl installed successfully!${NC}"
    else
        echo -e "${RED}kubectl is required to interact with clusters.${NC}"
        exit 1
    fi
}

# Check and install lazylinux
check_install_lazylinux() {
    # Check if 'vm' command is available in PATH (system installation)
    if command -v vm >/dev/null 2>&1; then
        echo -e "${GREEN}✓ vm (lazylinux) is already installed in system${NC}"
        return 0
    fi

    # Check if lazylinux is installed in user directory
    local lazylinux_bin="${LAZYLINUX_DIR}/bin/lazylinux"
    if [ -x "$lazylinux_bin" ]; then
        echo -e "${GREEN}✓ lazylinux is already installed in ~/.lazykube${NC}"
        return 0
    fi

    echo -e "${YELLOW}lazylinux (vm) is not installed${NC}"
    echo -e "${BLUE}Options:${NC}"
    echo "  1. Install via 'vm install' command (recommended)"
    echo "  2. Clone from GitHub to ~/.lazykube/lazylinux"
    echo ""
    read -p "Choose installation method [1/2/N]: " -n 1 -r
    echo

    if [[ $REPLY == "1" ]]; then
        echo -e "${BLUE}Installing lazylinux via 'vm install'...${NC}"
        if command -v vm >/dev/null 2>&1; then
            vm install
            echo -e "${GREEN}✓ lazylinux installed successfully!${NC}"
        else
            echo -e "${RED}Error: 'vm' command not found${NC}"
            echo "Please install vm first: https://github.com/antoniopicone/lazylinux"
            exit 1
        fi
    elif [[ $REPLY == "2" ]]; then
        echo -e "${BLUE}Downloading lazylinux from GitHub...${NC}"

        # Create directory
        mkdir -p "$LAZYLINUX_DIR"

        # Clone repository
        if [ -d "${LAZYLINUX_DIR}/.git" ]; then
            echo -e "${BLUE}Updating existing lazylinux installation...${NC}"
            cd "$LAZYLINUX_DIR"
            git pull
        else
            git clone https://github.com/antoniopicone/lazylinux.git "$LAZYLINUX_DIR"
        fi

        # Make executable
        chmod +x "${LAZYLINUX_DIR}/bin/lazylinux"

        echo -e "${GREEN}✓ lazylinux installed successfully!${NC}"
    else
        echo -e "${RED}lazylinux is required to create VMs.${NC}"
        exit 1
    fi
}

# Check and install sshpass
check_install_sshpass() {
    if command -v sshpass >/dev/null 2>&1; then
        echo -e "${GREEN}✓ sshpass is already installed${NC}"
        return 0
    fi

    echo -e "${YELLOW}sshpass is not installed (required for password-based SSH)${NC}"
    read -p "Install sshpass via Homebrew? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        check_homebrew
        echo -e "${BLUE}Installing sshpass via Homebrew...${NC}"
        brew install esolitos/ipa/sshpass
        echo -e "${GREEN}✓ sshpass installed successfully!${NC}"
    else
        echo -e "${RED}sshpass is required for SSH password authentication.${NC}"
        exit 1
    fi
}

# Install all dependencies
install_all_dependencies() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Checking Dependencies${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    check_install_ansible
    check_install_kubectl
    check_install_sshpass
    check_install_lazylinux

    # Install Ansible dependencies
    echo -e "${BLUE}Installing Ansible dependencies...${NC}"
    pip3 install --user kubernetes --quiet 2>/dev/null || true
    ansible-galaxy collection install -r "${LAZYKUBE_LIB_DIR}/requirements.yml" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}✓ All dependencies installed!${NC}"
    echo ""
}

# ============================================
# Cluster State Management Functions
# ============================================

# Create cluster directory structure
create_cluster_dir() {
    local cluster_name=$1
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"

    mkdir -p "${cluster_dir}/vms"
    mkdir -p "${cluster_dir}/inventory"
    mkdir -p "${cluster_dir}/group_vars"
    mkdir -p "${cluster_dir}/kubeconfig"

    echo "$cluster_dir"
}

# Save cluster metadata
save_cluster_metadata() {
    local cluster_name=$1
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"
    local domain=$2
    local haproxy_ip=$3
    local master1_ip=$4
    local master2_ip=$5
    local master3_ip=$6

    cat > "${cluster_dir}/cluster.json" << EOF
{
  "name": "$cluster_name",
  "domain": "$domain",
  "status": "active",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "vms": {
    "haproxy": {
      "name": "${cluster_name}-haproxy",
      "ip": "$haproxy_ip",
      "role": "load-balancer"
    },
    "master1": {
      "name": "${cluster_name}-master1",
      "ip": "$master1_ip",
      "role": "k3s-master"
    },
    "master2": {
      "name": "${cluster_name}-master2",
      "ip": "$master2_ip",
      "role": "k3s-master"
    },
    "master3": {
      "name": "${cluster_name}-master3",
      "ip": "$master3_ip",
      "role": "k3s-master"
    }
  }
}
EOF
}

# Update cluster status
update_cluster_status() {
    local cluster_name=$1
    local status=$2
    local cluster_file="${CLUSTERS_DIR}/${cluster_name}/cluster.json"

    if [ -f "$cluster_file" ]; then
        # Use jq if available, otherwise sed
        if command -v jq >/dev/null 2>&1; then
            local tmp=$(mktemp)
            jq --arg status "$status" '.status = $status' "$cluster_file" > "$tmp"
            mv "$tmp" "$cluster_file"
        else
            sed -i.bak "s/\"status\": \".*\"/\"status\": \"$status\"/" "$cluster_file"
            rm -f "${cluster_file}.bak"
        fi
    fi
}

# Get cluster metadata
get_cluster_metadata() {
    local cluster_name=$1
    local cluster_file="${CLUSTERS_DIR}/${cluster_name}/cluster.json"

    if [ -f "$cluster_file" ]; then
        cat "$cluster_file"
    else
        echo "{}"
    fi
}

# List all clusters
list_clusters() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Available Clusters${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ ! -d "$CLUSTERS_DIR" ] || [ -z "$(ls -A "$CLUSTERS_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No clusters found${NC}"
        echo ""
        echo "Create a cluster with: ${GREEN}lazykube create <cluster_name>${NC}"
        echo ""
        return
    fi

    for cluster_path in "$CLUSTERS_DIR"/*; do
        if [ -d "$cluster_path" ]; then
            local cluster_name=$(basename "$cluster_path")
            local cluster_file="${cluster_path}/cluster.json"

            if [ -f "$cluster_file" ]; then
                local status=$(grep -o '"status": "[^"]*"' "$cluster_file" | cut -d'"' -f4)
                local created=$(grep -o '"created_at": "[^"]*"' "$cluster_file" | cut -d'"' -f4)
                local domain=$(grep -o '"domain": "[^"]*"' "$cluster_file" | cut -d'"' -f4)

                echo -e "${GREEN}${cluster_name}${NC}"
                echo "  Status: $status"
                echo "  Domain: $domain"
                echo "  Created: $created"
                echo ""
            fi
        fi
    done
}

# Check if cluster exists
cluster_exists() {
    local cluster_name=$1
    [ -d "${CLUSTERS_DIR}/${cluster_name}" ]
}

# Delete cluster directory and metadata
delete_cluster_metadata() {
    local cluster_name=$1
    local cluster_dir="${CLUSTERS_DIR}/${cluster_name}"

    if [ -d "$cluster_dir" ]; then
        rm -rf "$cluster_dir"
        echo -e "${GREEN}✓ Cluster metadata deleted${NC}"
    fi
}

# ============================================
# VM Management Functions (using lazylinux)
# ============================================

# Get lazylinux binary path
get_lazylinux_bin() {
    # Prefer system 'vm' command if available
    if command -v vm >/dev/null 2>&1; then
        echo "vm"
    # Fall back to user installation
    elif [ -x "${LAZYLINUX_DIR}/bin/lazylinux" ]; then
        echo "${LAZYLINUX_DIR}/bin/lazylinux"
    else
        echo -e "${RED}Error: lazylinux not found${NC}" >&2
        echo -e "${YELLOW}Run 'lazykube create <cluster>' to install dependencies${NC}" >&2
        return 1
    fi
}

# Create VM using lazylinux
create_vm_lazylinux() {
    local vm_name=$1
    local cluster_name=$2
    local lazylinux_bin=$(get_lazylinux_bin)

    echo -e "${BLUE}Creating VM: $vm_name${NC}"

    # Call lazylinux to create VM
    # Note: This is a placeholder - actual lazylinux command may differ
    "$lazylinux_bin" create "$vm_name" --cluster "$cluster_name"
}

# Delete VM using lazylinux
delete_vm_lazylinux() {
    local vm_name=$1
    local lazylinux_bin=$(get_lazylinux_bin)

    echo -e "${BLUE}Deleting VM: $vm_name${NC}"

    # Call lazylinux to delete VM
    "$lazylinux_bin" delete "$vm_name" --force
}

# Get VM IP from lazylinux
get_vm_ip() {
    local vm_name=$1
    local lazylinux_bin=$(get_lazylinux_bin)

    # Get IP from lazylinux and extract just the IP address
    # Output format: "VM name IP Address: 192.168.105.46Connect with: ssh..."
    # We need to extract just the IP address (192.168.105.46)
    "$lazylinux_bin" ip "$vm_name" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
}

# ============================================
# Utility Functions
# ============================================

# Validate cluster name
validate_cluster_name() {
    local name=$1

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid cluster name${NC}"
        echo "Cluster name must contain only letters, numbers, hyphens, and underscores"
        exit 1
    fi
}

# Generate domain from cluster name
generate_domain() {
    local cluster_name=$1
    echo "${cluster_name}.local"
}

# Export functions for use in other scripts
export -f check_homebrew
export -f check_install_ansible
export -f check_install_kubectl
export -f check_install_lazylinux
export -f install_all_dependencies
export -f create_cluster_dir
export -f save_cluster_metadata
export -f update_cluster_status
export -f get_cluster_metadata
export -f list_clusters
export -f cluster_exists
export -f delete_cluster_metadata
export -f get_lazylinux_bin
export -f create_vm_lazylinux
export -f delete_vm_lazylinux
export -f get_vm_ip
export -f validate_cluster_name
export -f generate_domain
