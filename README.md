# K3s HA Cluster - Ansible Local Setup

Automated installation of a K3s HA cluster on 3 VMs + 1 HAProxy load balancer with interactive configuration.

## 🎯 Architecture

- **3 Master nodes**: K3s control-plane + embedded etcd
- **1 HAProxy**: Dedicated load balancer for API (6443), HTTP (80), HTTPS (443), etcd (2379/2380)
- **MetalLB**: Layer 2 LoadBalancer for internal services
- **Traefik**: Ingress controller with automatic TLS
- **cert-manager**: Self-signed certificate management

## 📋 Prerequisites

- 4 VMs with Debian/Ubuntu
- SSH enabled on all VMs
- Python 3 installed on the VMs
- `ansible`, `kubectl` installed on local Mac

## 🚀 Quick Start

### Option 1: Using the `lazykube` command (Recommended)

```bash
# The script is already executable, just run:
./lazykube configure
./lazykube install
./lazykube verify
```

**Optional: Install globally**

To use `lazykube` from anywhere without `./`:

```bash
# Option A: Add to your PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:/path/to/lazykube/directory"

# Option B: Create a symbolic link
sudo ln -s $(pwd)/lazykube /usr/local/bin/lazykube

# Now you can use it globally:
lazykube configure
lazykube install
```

### Option 2: Using `make` commands

```bash
cd ansible-local
make configure
```

### 1. Configure the cluster (interactive)

```bash
./lazykube configure
# or
make configure
```

The script interactively asks for:
- IP of each VM (3 masters + 1 HAProxy)
- SSH username for each VM
- SSH password **or** path to SSH private key
- Cluster domain (default: `k3cluster.local`)
- Timezone (default: `Europe/Rome`)

### 2. Verify connectivity

```bash
./lazykube check
# or
make check
```

### 3. Install the cluster (~15-20 minutes)

```bash
./lazykube install
# or
make install
```

**Note:** The default `install` command shows minimal output for a cleaner experience. If you want to see all installation stages and details, use:

```bash
./lazykube install-verbose
```

### 4. Configure kubectl

```bash
# Backup existing kubeconfig
cp ~/.kube/config ~/.kube/config.backup-$(date +%Y%m%d-%H%M%S)

# Merge with existing kubeconfig
KUBECONFIG=~/.kube/config:~/.kube/config-k3s-local kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config

# Switch to k3s-local cluster
kubectl config use-context k3s-local

# Verify
kubectl get nodes
```

### 5. Post-installation setup

After installation, configure DNS and import the CA certificate:

```bash
./lazykube dns-help
# or
make dns-help
```

This will show you:
1. **DNS configuration** - Add entries to `/etc/hosts` to access services via domain names
2. **CA certificate import** - Run `./lazykube trust-ca` to avoid SSL warnings in your browser

## 📖 Available Commands

You can use either `./lazykube <command>` or `make <command>` syntax.

**Examples:**
```bash
./lazykube help          # Show help
./lazykube configure     # Configure cluster
./lazykube install       # Install cluster
./lazykube verify        # Verify cluster status
```

### All Commands

### Setup and Configuration

- `lazykube configure` / `make configure` - **Configure VM IPs and credentials** (interactive) ⭐
- `lazykube config` / `make config` - Show current configuration
- `lazykube check` / `make check` - Verify SSH connectivity
- `lazykube setup` / `make setup` - Install Ansible dependencies

### Installation

- `lazykube install` / `make install` - **Install complete K3s HA cluster** (minimal output) ⭐
- `lazykube install-verbose` / `make install-verbose` - Installation with verbose output (shows all stages and details)

### Verification and Debug

- `lazykube verify` / `make verify` - Verify cluster status
- `lazykube logs` / `make logs` - Show component logs
- `lazykube dashboard` / `make dashboard` - Open Traefik dashboard
- `lazykube haproxy-stats` / `make haproxy-stats` - Open HAProxy stats dashboard

### Utilities

- `lazykube dns-help` / `make dns-help` - Show local DNS instructions
- `lazykube kubeconfig` / `make kubeconfig` - Instructions for kubeconfig merge
- `lazykube trust-ca` / `make trust-ca` - Import CA into system (macOS)

### Cleanup

- `lazykube uninstall` / `make uninstall` - Remove K3s cluster
- `lazykube clean` / `make clean` - Clean temporary files
- `lazykube clean-config` / `make clean-config` - Remove configuration

## 🔧 How It Works

### 1. `make configure` generates:

- `.cluster-config` - File with credentials (excluded from git)
- `inventories/hosts.yml` - Dynamic Ansible inventory
- Updates `group_vars/all.yml` with IPs

### 2. Example of interactive configuration:

```
IP Master 1 [192.168.105.46]: 192.168.1.10
SSH Username Master 1 [admin]: ubuntu
SSH Password Master 1: ********
SSH key path Master 1 []: ~/.ssh/id_rsa

IP Master 2 [192.168.105.47]: 192.168.1.11
SSH Username Master 2 [ubuntu]:
SSH Password Master 2:
SSH key path Master 2 [~/.ssh/id_rsa]:

IP Master 3 [192.168.105.48]: 192.168.1.12
SSH Username Master 3 [ubuntu]:
SSH Password Master 3:
SSH key path Master 3 [~/.ssh/id_rsa]:

IP HAProxy [192.168.105.49]: 192.168.1.100
SSH Username HAProxy [ubuntu]:
SSH Password HAProxy:
SSH key path HAProxy [~/.ssh/id_rsa]:

Cluster domain [k3cluster.local]:
Timezone [Europe/Rome]:
```

### 3. Automatically generated inventory:

```yaml
---
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    domain: "k3cluster.local"
    timezone: "Europe/Rome"

  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
            master1:
              ansible_host: 192.168.1.10
              ansible_user: ubuntu
              ansible_ssh_private_key_file: ~/.ssh/id_rsa
              k3s_node_name: k3s-master1
              is_first_master: true
            # ...
```

## 🔐 Security

### Credentials

- `.cluster-config` contains passwords/keys → **excluded from git**
- Use SSH keys instead of passwords when possible
- Never commit `inventories/hosts.yml` if it contains passwords

### TLS

- K3s uses TLS for all communications
- HAProxy uses TCP passthrough (does not terminate TLS)
- cert-manager generates self-signed certificates
- The kubeconfig uses `insecure-skip-tls-verify: true` (HAProxy IP not in certificate)

**To avoid SSL warnings in your browser:**
```bash
./lazykube trust-ca
```
This imports the self-signed CA certificate into your system keychain (macOS). After importing, restart your browser to access HTTPS services without warnings.

## 🐛 Troubleshooting

### Error: Cluster not configured

```bash
./lazykube configure
```

### Error: VMs unreachable

Test SSH manually:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.10
```

### TLS Error: certificate is valid for ... not <HAProxy_IP>

The generated kubeconfig already uses `insecure-skip-tls-verify: true`. This is normal with HAProxy.

For permanent fix (reinstall cluster):

```bash
ansible-playbook -i inventories/hosts.yml playbooks/reinstall-k3s.yml
```

### HAProxy backend DOWN

Verify master connectivity:

```bash
source .cluster-config
nc -zv $MASTER1_IP 6443
nc -zv $MASTER2_IP 6443
nc -zv $MASTER3_IP 6443
```

## 📁 File Structure

```
lazykube/
├── lazykube                      # Main CLI tool (wrapper for Makefile)
├── Makefile                      # Automated commands
├── .cluster-config               # Credentials (git ignored)
├── .gitignore
├── README.md
│
├── inventories/
│   └── hosts.yml                # Generated by configure-cluster.sh
│
├── group_vars/
│   └── all.yml                  # Updated by configure-cluster.sh
│
├── playbooks/
│   ├── install-cluster-local.yml
│   ├── reinstall-k3s.yml
│   └── regenerate-k3s-certs.yml
│
├── roles/
│   ├── haproxy-local/
│   ├── k3s-local/
│   ├── metallb-local/
│   ├── cert-manager-local/
│   └── traefik-local/
│
└── scripts/
    └── configure-cluster.sh     # Interactive configuration script
```

## 🔄 Complete Workflow

```bash
# 1. Configure IPs and credentials (once)
./lazykube configure

# 2. Verify SSH connectivity
./lazykube check

# 3. Install cluster (~15-20 min)
./lazykube install

# 4. Configure kubectl
KUBECONFIG=~/.kube/config:~/.kube/config-k3s-local kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
kubectl config use-context k3s-local

# 5. Post-installation setup (DNS + SSL certificates)
./lazykube dns-help          # Shows setup instructions
# Follow the instructions to:
# - Add DNS entries to /etc/hosts
# - Import CA certificate: ./lazykube trust-ca

# 6. Verify installation
./lazykube verify

# 7. Access dashboards (no SSL warnings after trust-ca!)
./lazykube haproxy-stats  # http://<HAPROXY_IP>:8404/stats
./lazykube dashboard      # https://traefik.k3cluster.local/dashboard/
```

## 📚 Additional Documentation

- [HAPROXY-SETUP.md](HAPROXY-SETUP.md) - Detailed HAProxy guide
- [FIX-TLS-CERTIFICATE.md](FIX-TLS-CERTIFICATE.md) - TLS troubleshooting
- [QUICK-START-HAPROXY.md](QUICK-START-HAPROXY.md) - Manual quick start

## License

MIT
