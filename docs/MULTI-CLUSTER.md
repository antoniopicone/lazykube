# Multi-Cluster Management

LazyKube now supports managing multiple Kubernetes clusters from a single installation. Each cluster has its own configuration stored in `~/.lazykube/clusters/`.

## Features

- **Multiple cluster configurations** - Create and manage unlimited clusters
- **Easy cluster switching** - Switch between clusters with a single command
- **Isolated configurations** - Each cluster has its own inventory, vars, and settings
- **LazyLinux integration** - Optional automatic VM creation
- **Improved SSH authentication** - Choose between SSH key OR password (not both)
- **Persistent storage** - Configurations survive project directory changes

## Quick Start

### 1. Create Your First Cluster

```bash
# Create a new cluster configuration
./lazykube cluster create production

# Configure the cluster (interactive)
./lazykube configure

# Install the cluster
./lazykube install
```

### 2. Create Additional Clusters

```bash
# Create development cluster
./lazykube cluster create development
./lazykube configure
./lazykube install

# Create staging cluster
./lazykube cluster create staging
./lazykube configure
./lazykube install
```

### 3. Switch Between Clusters

```bash
# List all clusters
./lazykube cluster list

# Switch to a different cluster
./lazykube cluster switch production

# Verify current cluster
./lazykube cluster current

# Show cluster details
./lazykube cluster info production
```

## Cluster Commands

### List Clusters

```bash
./lazykube cluster list
```

Shows all configured clusters with:
- Current cluster indicator (*)
- Cluster type (K3s or RKE2)
- Domain name
- IP addresses
- MetalLB range

### Create Cluster

```bash
./lazykube cluster create <cluster-name>
```

Creates a new cluster configuration. Cluster names must be alphanumeric with dashes or underscores.

**Examples:**
```bash
./lazykube cluster create prod
./lazykube cluster create dev-team-a
./lazykube cluster create staging_env
```

### Switch Cluster

```bash
./lazykube cluster switch <cluster-name>
# or
./lazykube cluster use <cluster-name>
```

Switches the active cluster. All subsequent commands will operate on this cluster.

### Delete Cluster

```bash
./lazykube cluster delete <cluster-name>
```

Deletes the cluster configuration (does NOT uninstall the actual cluster).

**⚠️ Warning:** This only removes the local configuration. To uninstall the actual cluster first:
```bash
./lazykube cluster switch <cluster-name>
./lazykube uninstall
./lazykube cluster delete <cluster-name>
```

### Show Current Cluster

```bash
./lazykube cluster current
```

Displays the name of the currently active cluster.

### Show Cluster Info

```bash
./lazykube cluster info [cluster-name]
```

Shows detailed information about a cluster. If no name is provided, shows info for the current cluster.

## Configuration Directory Structure

```
~/.lazykube/
├── current-cluster          # File containing current cluster name
└── clusters/
    ├── production/
    │   ├── .cluster-config  # Cluster configuration
    │   ├── hosts.yml        # Ansible inventory
    │   ├── all.yml          # Ansible group vars
    │   ├── ansible.cfg      # Cluster-specific Ansible config
    │   └── cluster-info.txt # Cluster metadata
    ├── development/
    │   └── ...
    └── staging/
        └── ...
```

## Enhanced Configure Script

The new configuration script offers improved UX:

### 1. VM Creation Methods

When configuring a cluster, you can choose:

**Option 1: LazyLinux Integration (Automatic)**
- Automatically creates VMs using LazyLinux
- Configures networking and resources
- Sets up SSH access

**Option 2: Manual Configuration**
- Enter IP addresses for existing VMs
- Configure SSH authentication
- Full control over infrastructure

### 2. Improved SSH Authentication

Choose authentication method **per node**:

**SSH Key (Recommended)**
- More secure
- No password prompts
- Automated operations

```
SSH Authentication method:
1) SSH Key (recommended)
2) Password
Choose [1/2]: 1
Path to SSH private key [~/.ssh/id_rsa]:
```

**Password Authentication**
- Simple setup
- Good for temporary clusters
- Requires sshpass

```
SSH Authentication method:
1) SSH Key (recommended)
2) Password
Choose [1/2]: 2
Password for antonio@192.168.105.100: ******
```

**Mixed Authentication**
You can use different methods for different nodes:
- HAProxy with key
- Master1 with password
- Master2 with key
- Master3 with key

### 3. Cluster Type Selection

Interactive comparison to help choose between K3s and RKE2:

```
┌────────────────────────────────────────────────────────────┐
│                K3s vs RKE2 Comparison                      │
├────────────────────────────────────────────────────────────┤
│ K3s                    │ RKE2                              │
├────────────────────────────────────────────────────────────┤
│ ✓ Lightweight          │ ✓ Security-focused (FIPS 140-2)  │
│ ✓ Quick install        │ ✓ CIS Kubernetes Benchmark        │
│ ✓ Perfect for dev/test │ ✓ Government & enterprise         │
│ ✓ IoT & Edge computing │ ✓ Production-grade security       │
└────────────────────────────────────────────────────────────┘
```

## LazyLinux Integration

LazyKube can integrate with [LazyLinux](https://github.com/antoniopicone/lazylinux) for automatic VM creation.

### Setup LazyLinux

```bash
# Clone LazyLinux
cd ~/Developer/antoniopicone
git clone https://github.com/antoniopicone/lazylinux.git
cd lazylinux

# Make executable
chmod +x lazylinux
```

### Use During Configuration

When running `./lazykube configure`:

```
How do you want to set up the VMs?
1) Use LazyLinux for automatic VM creation (recommended)
2) Manual configuration (I already have VMs)
Choose [1/2]: 1
```

LazyKube will detect LazyLinux and guide you through:
1. Number of master nodes (default: 3)
2. CPU cores per node (default: 2)
3. RAM per node in MB (default: 4096)
4. Disk size in GB (default: 50)
5. Base IP address

## Migrating Existing Clusters

If you have an existing LazyKube cluster, migrate it:

```bash
./scripts/migrate-existing-cluster.sh
```

This will:
1. Read your existing `.cluster-config`
2. Create a cluster in `~/.lazykube/clusters/`
3. Copy all configuration files
4. Set it as the current cluster
5. Create symlinks for compatibility

## Common Workflows

### Workflow 1: Production + Development Clusters

```bash
# Create production cluster
./lazykube cluster create prod
./lazykube configure  # Use RKE2, production IPs
./lazykube install

# Create development cluster
./lazykube cluster create dev
./lazykube configure  # Use K3s, dev IPs
./lazykube install

# Switch to dev for testing
./lazykube cluster switch dev
./lazykube verify

# Deploy to production
./lazykube cluster switch prod
kubectl apply -f production-app.yaml
```

### Workflow 2: Multi-Team Clusters

```bash
# Team A cluster
./lazykube cluster create team-a
./lazykube configure
./lazykube install

# Team B cluster
./lazykube cluster create team-b
./lazykube configure
./lazykube install

# Quick switching
./lazykube cluster switch team-a
kubectl get pods

./lazykube cluster switch team-b
kubectl get pods
```

### Workflow 3: Upgrade Testing

```bash
# Create test cluster for K3s v1.30
./lazykube cluster create k3s-v130-test
./lazykube configure  # Select K3s
./lazykube install

# Test the upgrade
./lazykube verify
kubectl apply -f test-workload.yaml

# If successful, upgrade production
./lazykube cluster switch prod-k3s
# Run upgrade playbook
```

## Troubleshooting

### Cluster Not Found

```
Error: No cluster configured.
Run 'lazykube configure' to set up a cluster.
```

**Solution:** Create and configure a cluster first:
```bash
./lazykube cluster create my-cluster
./lazykube configure
```

### Wrong Cluster Selected

```bash
# Check current cluster
./lazykube cluster current

# Switch to correct cluster
./lazykube cluster switch correct-cluster

# Verify
./lazykube cluster info
```

### Symlinks Not Working

If commands fail to find configuration:

```bash
# Re-link cluster configuration
./lazykube cluster switch $(./lazykube cluster current)
```

### Lost Cluster Configuration

Cluster configs are in `~/.lazykube/clusters/`. If you accidentally deleted one:

1. Recreate it:
   ```bash
   ./lazykube cluster create recovered-cluster
   ./lazykube configure
   ```

2. Or restore from backup if you have one

## Best Practices

### 1. Naming Conventions

Use descriptive cluster names:
- ✅ `production-us-east`
- ✅ `dev-team-backend`
- ✅ `staging-v2`
- ❌ `cluster1`
- ❌ `test`
- ❌ `asdf`

### 2. SSH Key Management

Use dedicated SSH keys per environment:
```bash
# Generate production key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s_prod_rsa

# Generate development key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k3s_dev_rsa
```

### 3. Document Your Clusters

Keep a separate document with:
- Cluster purpose
- Team/project owner
- VM specifications
- Network ranges
- Access credentials location

### 4. Regular Backups

Backup cluster configurations:
```bash
# Backup all clusters
tar -czf lazykube-clusters-$(date +%Y%m%d).tar.gz ~/.lazykube/

# Backup specific cluster
tar -czf prod-cluster-$(date +%Y%m%d).tar.gz ~/.lazykube/clusters/production/
```

### 5. Clean Up Unused Clusters

Regularly review and remove unused clusters:
```bash
./lazykube cluster list
./lazykube cluster delete old-test-cluster
```

## Advanced Usage

### Scripting Cluster Operations

```bash
#!/bin/bash
# Deploy app to all clusters

for cluster in $(ls ~/.lazykube/clusters/); do
    echo "Deploying to ${cluster}..."
    ./lazykube cluster switch ${cluster}
    kubectl apply -f app.yaml
done
```

### Export Cluster Configuration

```bash
# Export cluster config
tar -czf prod-cluster-export.tar.gz \
  ~/.lazykube/clusters/production/

# Import on another machine
tar -xzf prod-cluster-export.tar.gz -C ~/
./lazykube cluster switch production
```

### Cluster Templates

Create reusable cluster templates:
```bash
# Create template
./lazykube cluster create template-dev
./lazykube configure
# ... configure with standard dev settings ...

# Copy template for new team
cp -r ~/.lazykube/clusters/template-dev \
      ~/.lazykube/clusters/team-c-dev

# Edit team-specific settings
vim ~/.lazykube/clusters/team-c-dev/all.yml
```

## FAQ

**Q: Can I have multiple clusters running simultaneously?**
A: Yes! Each cluster is independent and can run at the same time.

**Q: Do clusters share kubeconfig?**
A: No, each cluster generates its own kubeconfig in `~/.kube/<domain>-config.yml`.

**Q: Can I rename a cluster?**
A: Yes, just rename the directory in `~/.lazykube/clusters/` and update `current-cluster` file if needed.

**Q: What happens if I delete the LazyKube project directory?**
A: Your cluster configurations in `~/.lazykube/` are safe! Just clone LazyKube again and run `./lazykube cluster list`.

**Q: Can I use LazyLinux for some clusters and manual config for others?**
A: Absolutely! Each cluster configuration is independent.

**Q: How do I backup all my clusters?**
A: Backup `~/.lazykube/` directory and individual kubeconfig files in `~/.kube/`.

## See Also

- [LazyLinux](https://github.com/antoniopicone/lazylinux) - Automatic VM creation
- [CNI Documentation](CNI.md) - Container networking
- [MONITORING Documentation](MONITORING.md) - Prometheus + Grafana
