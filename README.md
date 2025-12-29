# LazyKube v2.0.0

A powerful command-line tool for managing K3s High Availability (HA) clusters with automated VM provisioning using lazylinux.

## Features

- **Automated VM Provisioning**: Creates and manages VMs using lazylinux
- **K3s HA Cluster Deployment**: Deploys a production-ready K3s cluster with 3 master nodes
- **Load Balancing**: Automatic HAProxy configuration for HA
- **Multi-Cluster Management**: Create and manage multiple clusters
- **Simple CLI**: Easy-to-use command-line interface
- **Dependency Management**: Automatic installation of required tools

## Architecture

Each LazyKube cluster consists of:
- **3 Master Nodes**: K3s control-plane with embedded etcd
- **1 HAProxy Node**: Load balancer for API and ingress traffic
- **MetalLB**: L2 load balancer for services
- **Traefik**: Ingress controller with SSL/TLS support
- **cert-manager**: Automatic certificate management

## Installation

### From Source

```bash
git clone https://github.com/antoniopicone/lazykube.git
cd lazykube
./bin/lazykube install
```

### System Requirements

- macOS (Darwin)
- Homebrew (for dependency installation)
- SSH access to VMs (or lazylinux for VM creation)

## Quick Start

### 1. Create a Cluster

```bash
lazykube create my-cluster
```

This command will:
1. Check and install dependencies (ansible, kubectl, lazylinux)
2. Create 4 VMs using lazylinux
3. Configure HAProxy load balancer
4. Deploy K3s HA cluster
5. Install MetalLB, Traefik, and cert-manager

### 2. List Clusters

```bash
lazykube list
```

### 3. Access Dashboard

```bash
lazykube dashboard my-cluster
```

### 4. Delete a Cluster

```bash
lazykube delete my-cluster
```

## Command Reference

### Core Commands

#### `lazykube create <cluster_name>`
Create a new K3s HA cluster with VMs.

**Example:**
```bash
lazykube create production
```

#### `lazykube list`
Show all available clusters with their status.

**Example:**
```bash
lazykube list
```

#### `lazykube delete <cluster_name>`
Stop VMs and delete cluster.

**Example:**
```bash
lazykube delete production
```

#### `lazykube dashboard <cluster_name>`
Open the Traefik dashboard for a cluster.

**Example:**
```bash
lazykube dashboard production
```

### Management Commands

#### `lazykube install`
Install lazykube to system (/usr/local by default).

#### `lazykube uninstall`
Uninstall lazykube from system.

#### `lazykube version`
Show version information.

## Configuration

### Cluster Storage

Each cluster's configuration is stored in:
```
~/.lazykube/clusters/<cluster_name>/
├── cluster.json          # Cluster metadata
├── cluster-config        # VM and SSH configuration
├── inventory/            # Ansible inventory
│   └── hosts.yml
├── group_vars/           # Ansible variables
│   └── all.yml
├── kubeconfig/           # Kubernetes configuration
│   └── config.yml
└── vms/                  # VM information
    └── vm_info.txt
```

### Cluster Metadata

The `cluster.json` file contains:
- Cluster name and domain
- Creation timestamp
- VM information (names, IPs, roles)
- Status (active, stopped, etc.)

## Post-Installation Setup

### 1. Configure kubectl

```bash
export KUBECONFIG=~/.lazykube/clusters/my-cluster/kubeconfig/config.yml
kubectl get nodes
```

### 2. Configure Local DNS

Add entries to `/etc/hosts`:

```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# K3s Cluster: my-cluster
<HAPROXY_IP>  traefik.my-cluster.local
<HAPROXY_IP>  demo.my-cluster.local
EOF'
```

### 3. Import CA Certificate (Optional)

To avoid SSL warnings:

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.kube/k3s-local-ca.crt
```

## Dependencies

LazyKube automatically checks and installs:

1. **Ansible**: Configuration management
2. **kubectl**: Kubernetes CLI
3. **lazylinux**: VM management tool

All dependencies are installed via Homebrew on macOS.

## Networking

### Default IP Ranges

- **VMs**: 192.168.105.50-53
- **MetalLB Pool**: Defined in cluster configuration
- **Services**: Exposed via HAProxy on standard ports (80, 443, 6443)

### Ports

- **6443**: Kubernetes API (via HAProxy)
- **80/443**: HTTP/HTTPS ingress (via HAProxy → Traefik)
- **8404**: HAProxy stats dashboard
- **2379/2380**: etcd (internal)

## Troubleshooting

### VM Issues

Check VM status:
```bash
~/.lazykube/lazylinux/bin/lazylinux list
```

### Cluster Connectivity

Test SSH connectivity:
```bash
ansible all -i ~/.lazykube/clusters/<cluster_name>/inventory/hosts.yml -m ping
```

### Kubernetes Issues

Check cluster status:
```bash
export KUBECONFIG=~/.lazykube/clusters/<cluster_name>/kubeconfig/config.yml
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

### View Logs

Check component logs:
```bash
kubectl logs -n metallb-system -l component=controller
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
kubectl logs -n cert-manager -l app=cert-manager
```

## Advanced Usage

### Custom VM Configuration

Edit cluster configuration before deployment:
```bash
vi ~/.lazykube/clusters/<cluster_name>/cluster-config
```

### Manual Ansible Playbook Execution

```bash
cd /usr/local/lib/lazykube
ansible-playbook \
  -i ~/.lazykube/clusters/<cluster_name>/inventory/hosts.yml \
  playbooks/install-cluster-local.yml
```

## Architecture Details

### Component Flow

1. **lazykube CLI** → Validates input, manages workflow
2. **helpers.sh** → Dependency checks, cluster state management
3. **provision-vms.sh** → VM creation via lazylinux
4. **Ansible Playbooks** → K3s and component deployment
5. **cluster.json** → Persistent cluster state

### File Structure

```
lazykube/
├── bin/
│   └── lazykube              # Main CLI script
├── lib/
│   ├── scripts/
│   │   ├── helpers.sh        # Helper functions
│   │   └── provision-vms.sh  # VM provisioning
│   ├── playbooks/            # Ansible playbooks
│   ├── roles/                # Ansible roles
│   ├── ansible.cfg           # Ansible configuration
│   └── Makefile              # Legacy make targets
└── share/
    ├── templates/            # Configuration templates
    └── examples/             # Example manifests
```

## Contributing

Contributions are welcome! Please submit pull requests or open issues on GitHub.

## License

MIT License - see LICENSE file for details

## Links

- GitHub: https://github.com/antoniopicone/lazykube
- lazylinux: https://github.com/antoniopicone/lazylinux

## Version History

### v2.0.0 (Current)
- Complete refactor with new command structure
- Integrated lazylinux for VM management
- Multi-cluster support
- Improved state management
- Enhanced dependency handling

### v1.0.0
- Initial release
- Manual VM configuration
- Single cluster support
