#!/usr/bin/env bash

# LazyKube Cluster Manager
# Manages multiple cluster configurations in ~/.lazykube/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# LazyKube home directory
LAZYKUBE_HOME="${HOME}/.lazykube"
CLUSTERS_DIR="${LAZYKUBE_HOME}/clusters"
CURRENT_CLUSTER_FILE="${LAZYKUBE_HOME}/current-cluster"

# Create LazyKube directory structure
init_lazykube_home() {
    mkdir -p "${CLUSTERS_DIR}"

    if [ ! -f "${CURRENT_CLUSTER_FILE}" ]; then
        echo "" > "${CURRENT_CLUSTER_FILE}"
    fi
}

# List all clusters
list_clusters() {
    echo -e "${BLUE}Available clusters:${NC}"
    echo ""

    if [ ! -d "${CLUSTERS_DIR}" ] || [ -z "$(ls -A ${CLUSTERS_DIR} 2>/dev/null)" ]; then
        echo -e "${YELLOW}No clusters configured yet.${NC}"
        echo "Run 'lazykube cluster create' to create your first cluster."
        return
    fi

    local current_cluster=$(cat "${CURRENT_CLUSTER_FILE}" 2>/dev/null || echo "")

    for cluster_dir in "${CLUSTERS_DIR}"/*; do
        if [ -d "${cluster_dir}" ]; then
            local cluster_name=$(basename "${cluster_dir}")
            local marker=" "

            if [ "${cluster_name}" = "${current_cluster}" ]; then
                marker="*"
                echo -e "${GREEN}${marker} ${cluster_name} (current)${NC}"
            else
                echo -e "  ${cluster_name}"
            fi

            # Show cluster info
            if [ -f "${cluster_dir}/cluster-info.txt" ]; then
                cat "${cluster_dir}/cluster-info.txt" | sed 's/^/    /'
            fi
            echo ""
        fi
    done
}

# Get current cluster
get_current_cluster() {
    if [ -f "${CURRENT_CLUSTER_FILE}" ]; then
        cat "${CURRENT_CLUSTER_FILE}"
    fi
}

# Set current cluster
set_current_cluster() {
    local cluster_name=$1
    local cluster_path="${CLUSTERS_DIR}/${cluster_name}"

    if [ ! -d "${cluster_path}" ]; then
        echo -e "${RED}Error: Cluster '${cluster_name}' does not exist.${NC}"
        exit 1
    fi

    echo "${cluster_name}" > "${CURRENT_CLUSTER_FILE}"
    echo -e "${GREEN}✓ Switched to cluster: ${cluster_name}${NC}"
}

# Create new cluster configuration
create_cluster() {
    local cluster_name=$1

    if [ -z "${cluster_name}" ]; then
        echo -e "${RED}Error: Cluster name is required.${NC}"
        echo "Usage: lazykube cluster create <cluster-name>"
        exit 1
    fi

    # Validate cluster name (alphanumeric, dash, underscore)
    if ! [[ "${cluster_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid cluster name. Use only letters, numbers, dash, and underscore.${NC}"
        exit 1
    fi

    local cluster_path="${CLUSTERS_DIR}/${cluster_name}"

    if [ -d "${cluster_path}" ]; then
        echo -e "${RED}Error: Cluster '${cluster_name}' already exists.${NC}"
        exit 1
    fi

    mkdir -p "${cluster_path}"
    echo "${cluster_name}" > "${CURRENT_CLUSTER_FILE}"

    echo -e "${GREEN}✓ Created cluster configuration: ${cluster_name}${NC}"
    echo -e "${BLUE}Run 'lazykube configure' to configure this cluster.${NC}"
}

# Delete cluster configuration
delete_cluster() {
    local cluster_name=$1

    if [ -z "${cluster_name}" ]; then
        echo -e "${RED}Error: Cluster name is required.${NC}"
        echo "Usage: lazykube cluster delete <cluster-name>"
        exit 1
    fi

    local cluster_path="${CLUSTERS_DIR}/${cluster_name}"

    if [ ! -d "${cluster_path}" ]; then
        echo -e "${RED}Error: Cluster '${cluster_name}' does not exist.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Are you sure you want to delete cluster '${cluster_name}'?${NC}"
    echo -e "${YELLOW}This will remove all configuration files but NOT uninstall the cluster.${NC}"
    read -p "Type 'yes' to confirm: " confirm

    if [ "${confirm}" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi

    rm -rf "${cluster_path}"

    # If this was the current cluster, clear it
    local current=$(get_current_cluster)
    if [ "${current}" = "${cluster_name}" ]; then
        echo "" > "${CURRENT_CLUSTER_FILE}"
    fi

    echo -e "${GREEN}✓ Deleted cluster configuration: ${cluster_name}${NC}"
}

# Export cluster path for use by other scripts
get_cluster_path() {
    local cluster_name=$(get_current_cluster)

    if [ -z "${cluster_name}" ]; then
        echo ""
        return 1
    fi

    echo "${CLUSTERS_DIR}/${cluster_name}"
}

# Show cluster info
show_cluster_info() {
    local cluster_name=$1

    if [ -z "${cluster_name}" ]; then
        cluster_name=$(get_current_cluster)
    fi

    if [ -z "${cluster_name}" ]; then
        echo -e "${RED}Error: No cluster selected.${NC}"
        exit 1
    fi

    local cluster_path="${CLUSTERS_DIR}/${cluster_name}"

    if [ ! -d "${cluster_path}" ]; then
        echo -e "${RED}Error: Cluster '${cluster_name}' does not exist.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Cluster: ${cluster_name}${NC}"
    echo -e "${BLUE}Path: ${cluster_path}${NC}"
    echo ""

    if [ -f "${cluster_path}/cluster-info.txt" ]; then
        cat "${cluster_path}/cluster-info.txt"
    else
        echo "No configuration yet. Run 'lazykube configure' to set up this cluster."
    fi
}

# Main command handler
case "${1:-list}" in
    list)
        init_lazykube_home
        list_clusters
        ;;
    create)
        init_lazykube_home
        create_cluster "$2"
        ;;
    delete)
        init_lazykube_home
        delete_cluster "$2"
        ;;
    switch|use)
        init_lazykube_home
        set_current_cluster "$2"
        ;;
    current)
        init_lazykube_home
        current=$(get_current_cluster)
        if [ -n "${current}" ]; then
            echo "${current}"
        else
            echo -e "${YELLOW}No cluster selected.${NC}"
        fi
        ;;
    path)
        init_lazykube_home
        get_cluster_path || echo ""
        ;;
    info)
        init_lazykube_home
        show_cluster_info "$2"
        ;;
    *)
        echo "Usage: $0 {list|create|delete|switch|current|path|info} [cluster-name]"
        exit 1
        ;;
esac
