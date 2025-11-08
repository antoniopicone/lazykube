# Nginx Demo - Helm Chart

This is the Helm chart version of the nginx-demo application, equivalent to the `nginx-demo-local.yaml` manifest.

## Prerequisites

- Kubernetes cluster (K3s or RKE2) installed via LazyKube
- Helm 3.x installed
- cert-manager with `ca-issuer` ClusterIssuer configured
- Traefik ingress controller installed

## Installation Commands

### Basic Installation

Install the chart in the `demo` namespace:

```bash
# Create namespace
kubectl create namespace demo

# Install with Helm
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo
```

### Installation with Custom Values

```bash
# Install with custom domain
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --set ingress.hosts[0].host=demo.mydomain.local \
  --set certificate.dnsNames[0]=demo.mydomain.local
```

### Installation with Custom Values File

Create a custom `my-values.yaml`:

```yaml
replicaCount: 3

ingress:
  hosts:
    - host: demo.mydomain.local
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: demo-tls
      hosts:
        - demo.mydomain.local

certificate:
  dnsNames:
    - demo.mydomain.local
```

Install with custom values:

```bash
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --values my-values.yaml
```

## Equivalent Commands

### Kubectl vs Helm Comparison

**Using kubectl (manifest):**
```bash
kubectl create namespace demo
kubectl apply -f examples/nginx-demo-local.yaml
```

**Using Helm (chart):**
```bash
kubectl create namespace demo
helm install nginx-demo ./examples/nginx-demo-helm --namespace demo
```

## Verification

After installation, verify the deployment:

```bash
# Check all resources
helm status nginx-demo --namespace demo

# Check pods
kubectl get pods -n demo

# Check ingress
kubectl get ingress -n demo

# Check certificate
kubectl get certificate -n demo

# Test the application
curl -k https://demo.k3cluster.local
```

## Upgrade

Update the deployment:

```bash
# Modify values.yaml or use --set flags
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --set replicaCount=3
```

## Uninstall

Remove the application:

```bash
# Uninstall with Helm
helm uninstall nginx-demo --namespace demo

# Remove namespace (optional)
kubectl delete namespace demo
```

## Configuration

Key configurable values in `values.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of nginx replicas | `2` |
| `image.repository` | Nginx image repository | `nginx` |
| `image.tag` | Nginx image tag | `alpine` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `traefik` |
| `ingress.hosts[0].host` | Hostname | `demo.k3cluster.local` |
| `certificate.enabled` | Enable cert-manager certificate | `true` |
| `certificate.issuerRef.name` | ClusterIssuer name | `ca-issuer` |

## Advanced Usage

### Template Rendering

Preview the rendered templates without installing:

```bash
helm template nginx-demo ./examples/nginx-demo-helm \
  --namespace demo
```

### Dry Run

Test installation without actually deploying:

```bash
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --dry-run --debug
```

### Package the Chart

Create a chart archive:

```bash
helm package ./examples/nginx-demo-helm
```

This creates `nginx-demo-1.0.0.tgz` that can be distributed and installed from anywhere.

### Install from Package

```bash
helm install nginx-demo nginx-demo-1.0.0.tgz --namespace demo
```

## Differences from kubectl apply

### Advantages of Helm

1. **Versioning**: Track releases and rollback easily
   ```bash
   helm rollback nginx-demo 1 --namespace demo
   ```

2. **Templating**: Reuse charts with different values
   ```bash
   helm install demo1 ./chart --set ingress.hosts[0].host=demo1.local
   helm install demo2 ./chart --set ingress.hosts[0].host=demo2.local
   ```

3. **Release Management**: View release history
   ```bash
   helm history nginx-demo --namespace demo
   ```

4. **Atomic Deployments**: Rollback automatically on failure
   ```bash
   helm install nginx-demo ./chart --atomic --namespace demo
   ```

5. **Easy Upgrades**: Update deployments with new values
   ```bash
   helm upgrade nginx-demo ./chart --reuse-values --set replicaCount=5
   ```

### When to Use Each

**Use kubectl apply when:**
- Simple, one-time deployments
- Learning Kubernetes
- Quick testing
- Static configurations

**Use Helm when:**
- Managing multiple environments (dev, staging, prod)
- Need version control and rollback
- Deploying complex applications
- Sharing/distributing applications
- Need templating and customization

## Troubleshooting

### Check Helm Release Status

```bash
helm status nginx-demo --namespace demo
```

### View Rendered Values

```bash
helm get values nginx-demo --namespace demo
```

### View All Resources

```bash
helm get manifest nginx-demo --namespace demo
```

### Debug Installation Issues

```bash
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --dry-run --debug
```
