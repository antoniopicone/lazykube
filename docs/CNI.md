# Container Network Interface (CNI)

## What is CNI?

The **Container Network Interface (CNI)** is the networking layer of Kubernetes. It's responsible for:

- **Pod IP Assignment**: Each pod gets a unique IP address
- **Pod-to-Pod Communication**: Enables pods on different nodes to communicate
- **Network Policies**: Firewall rules between pods (security)
- **Service Networking**: Load balancing and service discovery
- **Ingress Traffic**: External traffic routing to pods

**Without a CNI plugin, pods cannot communicate with each other!**

## CNI Options

LazyKube supports multiple CNI plugins for both K3s and RKE2:

| CNI      | Performance | Security | Observability | Use Case                    |
|----------|-------------|----------|---------------|-----------------------------|
| **Cilium** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐   | Production, Advanced features |
| **Calico** | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐       | Enterprise, Network Policies |
| **Flannel**| ⭐⭐⭐     | ⭐⭐⭐    | ⭐⭐         | Simple, Lightweight         |
| **Canal** | ⭐⭐⭐⭐   | ⭐⭐⭐⭐   | ⭐⭐⭐       | Flannel + Calico policies   |

### Cilium (Default)

**Why Cilium?**
- eBPF-based (kernel-level performance)
- Advanced observability with Hubble
- Network policies (Layer 3/4 and Layer 7)
- Service mesh capabilities
- Transparent encryption
- Multi-cluster connectivity

**Configuration**: Set in `group_vars/all.yml`:
```yaml
rke2_cni: "cilium"  # Options: cilium, calico, canal
```

## Verify CNI Installation

### 1. Check CNI Pods

```bash
# View Cilium pods (one per node)
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

# Expected output:
NAME           READY   STATUS    RESTARTS   AGE     IP               NODE
cilium-gnzj8   1/1     Running   0          4h      192.168.105.94   rke2n2
cilium-p5r9h   1/1     Running   0          4h      192.168.105.93   rke2n1
cilium-rfzc8   1/1     Running   0          4h      192.168.105.95   rke2n3
```

### 2. Check CNI Status

```bash
# Get detailed Cilium status
kubectl exec -n kube-system cilium-p5r9h -- cilium status

# Brief status
kubectl exec -n kube-system cilium-p5r9h -- cilium status --brief
# Output: OK
```

### 3. Check CNI DaemonSet

```bash
kubectl get ds -n kube-system cilium

# Expected output:
NAME     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
cilium   3         3         3       3            3
```

## Test CNI Connectivity

### Test 1: Internet Connectivity

```bash
# Pod can reach external internet
kubectl run test-internet --image=curlimages/curl --restart=Never --rm -i -- \
  curl -s https://www.google.com -o /dev/null && echo "OK"
```

### Test 2: Pod-to-Pod Communication

```bash
# Create nginx pod
kubectl run nginx --image=nginx:alpine --port=80

# Get nginx pod IP
NGINX_IP=$(kubectl get pod nginx -o jsonpath='{.status.podIP}')
echo "Nginx IP: $NGINX_IP"

# Test connectivity from another pod
kubectl run test-pod --image=curlimages/curl --restart=Never --rm -i -- \
  curl -s http://$NGINX_IP | grep "Welcome to nginx"

# Cleanup
kubectl delete pod nginx
```

### Test 3: DNS Resolution

```bash
# Create service
kubectl run nginx --image=nginx:alpine --port=80
kubectl expose pod nginx --port=80 --name=nginx-svc

# Test DNS resolution
kubectl run dns-test --image=curlimages/curl --restart=Never --rm -i -- \
  curl -s http://nginx-svc | grep "Welcome to nginx"

# Cleanup
kubectl delete pod nginx
kubectl delete svc nginx-svc
```

## CNI Configuration Details

### Cilium Configuration (RKE2)

Location: `/etc/rancher/rke2/config.yaml`

```yaml
# CNI plugin
cni: cilium

# Disable default CNI (we use Cilium)
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server
```

### Cilium Features

1. **IP Address Management (IPAM)**
   - Each node gets a /24 subnet (e.g., 10.42.0.0/24)
   - 254 IPs available per node
   - Automatic IP allocation to pods

2. **Network Mode**
   - **Tunnel mode (VXLAN)**: Overlay network, works everywhere
   - **Direct routing**: Better performance, requires BGP

3. **Network Policies**
   - Layer 3/4 (IP/Port filtering)
   - Layer 7 (HTTP/gRPC filtering)
   - DNS-based policies

## Common CNI Commands

### Cilium Commands

```bash
# Get Cilium status
kubectl exec -n kube-system <cilium-pod> -- cilium status

# List all endpoints (pods)
kubectl exec -n kube-system <cilium-pod> -- cilium endpoint list

# Check connectivity between nodes
kubectl exec -n kube-system <cilium-pod> -- cilium node list

# View BPF maps
kubectl exec -n kube-system <cilium-pod> -- cilium bpf endpoint list

# Monitor network traffic
kubectl exec -n kube-system <cilium-pod> -- cilium monitor
```

### Debug Network Issues

```bash
# Check if CNI is working
kubectl get nodes -o wide
kubectl get pods -o wide

# Create debug pod
kubectl run debug --image=nicolaka/netshoot --restart=Never -- sleep 3600

# Exec into debug pod
kubectl exec -it debug -- bash

# Inside pod:
ping 8.8.8.8              # Test internet
ping <pod-ip>             # Test pod-to-pod
nslookup kubernetes       # Test DNS
traceroute <pod-ip>       # Check routing
```

## Network Policies

### Example: Deny All Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### Example: Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Advanced: Enable Hubble (Cilium Observability)

Hubble provides network observability and monitoring for Cilium.

### Install Hubble CLI

```bash
# macOS
brew install hubble

# Linux
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
```

### Enable Hubble

```bash
# Enable Hubble relay
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.18/install/kubernetes/quick-hubble.yaml

# Port-forward Hubble relay
kubectl port-forward -n kube-system deployment/hubble-relay 4245:4245

# View network flows
hubble observe

# View flows from specific pod
hubble observe --from-pod default/nginx

# View HTTP traffic
hubble observe --protocol http
```

## Troubleshooting

### CNI Pods Not Running

```bash
# Check pod logs
kubectl logs -n kube-system <cilium-pod>

# Check CNI config
kubectl exec -n kube-system <cilium-pod> -- cat /host/etc/cni/net.d/05-cilium.conflist

# Restart CNI
kubectl rollout restart ds/cilium -n kube-system
```

### Pods Can't Communicate

1. Check if CNI is healthy:
   ```bash
   kubectl exec -n kube-system <cilium-pod> -- cilium status
   ```

2. Check network policies:
   ```bash
   kubectl get networkpolicies -A
   ```

3. Check pod IPs:
   ```bash
   kubectl get pods -o wide
   ```

4. Test connectivity:
   ```bash
   kubectl run debug --image=nicolaka/netshoot --rm -it -- ping <target-ip>
   ```

### DNS Not Working

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS
kubectl run dns-test --image=busybox --rm -it -- nslookup kubernetes

# Check DNS config
kubectl exec -n kube-system <coredns-pod> -- cat /etc/coredns/Corefile
```

## Additional Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [CNI Specification](https://github.com/containernetworking/cni)
- [Hubble Observability](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
