#!/usr/bin/env bash

# Migrate existing cluster configuration to new multi-cluster system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAZYKUBE_HOME="${HOME}/.lazykube"
CLUSTERS_DIR="${LAZYKUBE_HOME}/clusters"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Migrating existing cluster configuration to multi-cluster system...${NC}"
echo ""

# Check if old config exists
if [ ! -f "${PROJECT_ROOT}/.cluster-config" ]; then
    echo -e "${YELLOW}No existing cluster configuration found.${NC}"
    echo "Nothing to migrate."
    exit 0
fi

# Source old config
source "${PROJECT_ROOT}/.cluster-config"

# Determine cluster name from domain or ask user
if [ -n "${DOMAIN}" ]; then
    suggested_name=$(echo "${DOMAIN}" | sed 's/\.dev$//' | sed 's/\./-/g')
else
    suggested_name="default"
fi

echo -e "${YELLOW}Found existing cluster configuration.${NC}"
echo "Suggested cluster name: ${suggested_name}"
read -p "Enter cluster name (or press Enter to use suggested): " cluster_name
cluster_name=${cluster_name:-$suggested_name}

# Create cluster directory
mkdir -p "${CLUSTERS_DIR}/${cluster_name}"

# Copy configuration files
echo "Copying configuration files..."

cp "${PROJECT_ROOT}/.cluster-config" "${CLUSTERS_DIR}/${cluster_name}/.cluster-config"

if [ -f "${PROJECT_ROOT}/inventories/hosts.yml" ]; then
    cp "${PROJECT_ROOT}/inventories/hosts.yml" "${CLUSTERS_DIR}/${cluster_name}/hosts.yml"
fi

if [ -f "${PROJECT_ROOT}/group_vars/all.yml" ]; then
    cp "${PROJECT_ROOT}/group_vars/all.yml" "${CLUSTERS_DIR}/${cluster_name}/all.yml"
fi

# Create cluster info
if [ -n "${CLUSTER_TYPE}" ] && [ -n "${DOMAIN}" ]; then
    cat > "${CLUSTERS_DIR}/${cluster_name}/cluster-info.txt" << EOF
Type: ${CLUSTER_TYPE}
Domain: ${DOMAIN}
HAProxy: ${HAPROXY_IP:-N/A}
Masters: ${MASTER1_IP:-N/A}, ${MASTER2_IP:-N/A}, ${MASTER3_IP:-N/A}
MetalLB: ${METALLB_RANGE:-N/A}
EOF
fi

# Set as current cluster
echo "${cluster_name}" > "${LAZYKUBE_HOME}/current-cluster"

# Create symlinks
ln -sf "${CLUSTERS_DIR}/${cluster_name}/hosts.yml" "${PROJECT_ROOT}/inventories/hosts.yml" 2>/dev/null || true
ln -sf "${CLUSTERS_DIR}/${cluster_name}/all.yml" "${PROJECT_ROOT}/group_vars/all.yml" 2>/dev/null || true
ln -sf "${CLUSTERS_DIR}/${cluster_name}/.cluster-config" "${PROJECT_ROOT}/.cluster-config" 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Migration complete!${NC}"
echo ""
echo -e "${BLUE}Cluster '${cluster_name}' has been imported and set as current.${NC}"
echo ""
echo "You can now:"
echo "  - lazykube cluster list          # See all clusters"
echo "  - lazykube cluster create <name> # Create new clusters"
echo "  - lazykube cluster switch <name> # Switch between clusters"
echo ""
