# Helm vs kubectl: Quick Reference Guide

This guide shows the equivalent commands for deploying the nginx-demo application using both methods.

## Quick Comparison

| Task | kubectl | Helm |
|------|---------|------|
| **Install** | `kubectl apply -f manifest.yaml` | `helm install <name> <chart>` |
| **Update** | `kubectl apply -f manifest.yaml` | `helm upgrade <name> <chart>` |
| **Uninstall** | `kubectl delete -f manifest.yaml` | `helm uninstall <name>` |
| **Status** | `kubectl get all -n <namespace>` | `helm status <name>` |
| **Rollback** | Manual reapply previous version | `helm rollback <name> <revision>` |

## Installation

### Using kubectl (Manifest)

```bash
# Create namespace
kubectl create namespace demo

# Deploy application
kubectl apply -f examples/nginx-demo-local.yaml

# Verify deployment
kubectl get all -n demo
kubectl get ingress -n demo
kubectl get certificate -n demo
```

### Using Helm (Chart)

```bash
# Create namespace
kubectl create namespace demo

# Install chart
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo

# Verify deployment
helm status nginx-demo --namespace demo
kubectl get all -n demo
```

## Customization

### kubectl: Edit manifest file

```bash
# Edit the YAML file
vim examples/nginx-demo-local.yaml

# Change replicas from 2 to 3
# spec:
#   replicas: 3

# Apply changes
kubectl apply -f examples/nginx-demo-local.yaml
```

### Helm: Use values or set flags

**Option 1: Override specific values**
```bash
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --set replicaCount=3 \
  --set ingress.hosts[0].host=demo.mydomain.local
```

**Option 2: Use custom values file**
```bash
# Create custom-values.yaml
cat > custom-values.yaml <<EOF
replicaCount: 3
ingress:
  hosts:
    - host: demo.mydomain.local
      paths:
        - path: /
          pathType: Prefix
EOF

# Upgrade with custom values
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --values custom-values.yaml
```

## Updates

### kubectl: Reapply manifest

```bash
# Modify the manifest file
vim examples/nginx-demo-local.yaml

# Apply updated manifest
kubectl apply -f examples/nginx-demo-local.yaml

# Check rollout status
kubectl rollout status deployment/nginx-demo -n demo
```

### Helm: Upgrade release

```bash
# Upgrade with new values
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --set image.tag=latest

# Or upgrade with modified chart
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --reuse-values
```

## Rollback

### kubectl: Manual rollback

```bash
# View rollout history
kubectl rollout history deployment/nginx-demo -n demo

# Rollback to previous version
kubectl rollout undo deployment/nginx-demo -n demo

# Rollback to specific revision
kubectl rollout undo deployment/nginx-demo -n demo --to-revision=2
```

### Helm: Automatic rollback

```bash
# View release history
helm history nginx-demo --namespace demo

# Rollback to previous release
helm rollback nginx-demo --namespace demo

# Rollback to specific revision
helm rollback nginx-demo 1 --namespace demo
```

## Status & Information

### kubectl: Multiple commands

```bash
# Get all resources
kubectl get all -n demo

# Get specific resources
kubectl get deployment nginx-demo -n demo
kubectl get pods -n demo
kubectl get svc nginx-demo -n demo
kubectl get ingress nginx-demo -n demo

# Describe resources
kubectl describe deployment nginx-demo -n demo

# View logs
kubectl logs -n demo -l app=nginx-demo
```

### Helm: Unified commands

```bash
# Get release status
helm status nginx-demo --namespace demo

# Get release values
helm get values nginx-demo --namespace demo

# Get all manifests
helm get manifest nginx-demo --namespace demo

# View release history
helm history nginx-demo --namespace demo

# View logs (still use kubectl)
kubectl logs -n demo -l app.kubernetes.io/name=nginx-demo
```

## Uninstallation

### kubectl: Delete resources

```bash
# Delete using manifest
kubectl delete -f examples/nginx-demo-local.yaml

# Or delete by label
kubectl delete all -n demo -l app=nginx-demo

# Delete namespace
kubectl delete namespace demo
```

### Helm: Uninstall release

```bash
# Uninstall release (keeps history)
helm uninstall nginx-demo --namespace demo

# Uninstall and purge history
helm uninstall nginx-demo --namespace demo --no-hooks

# Delete namespace
kubectl delete namespace demo
```

## Multiple Environments

### kubectl: Separate manifests

```bash
# dev-manifest.yaml
kubectl apply -f examples/nginx-demo-dev.yaml

# staging-manifest.yaml
kubectl apply -f examples/nginx-demo-staging.yaml

# prod-manifest.yaml
kubectl apply -f examples/nginx-demo-prod.yaml
```

### Helm: One chart, multiple values

```bash
# Dev environment
helm install nginx-demo-dev ./examples/nginx-demo-helm \
  --namespace dev \
  --values values-dev.yaml

# Staging environment
helm install nginx-demo-staging ./examples/nginx-demo-helm \
  --namespace staging \
  --values values-staging.yaml

# Production environment
helm install nginx-demo-prod ./examples/nginx-demo-helm \
  --namespace prod \
  --values values-prod.yaml
```

## Testing Before Deployment

### kubectl: Apply with --dry-run

```bash
# Server-side dry run
kubectl apply -f examples/nginx-demo-local.yaml --dry-run=server

# Client-side dry run
kubectl apply -f examples/nginx-demo-local.yaml --dry-run=client
```

### Helm: Template and dry-run

```bash
# Render templates without installing
helm template nginx-demo ./examples/nginx-demo-helm \
  --namespace demo

# Dry run installation
helm install nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --dry-run --debug

# Test chart for issues
helm lint ./examples/nginx-demo-helm
```

## Complete Example Workflows

### kubectl Workflow

```bash
# 1. Deploy
kubectl create namespace demo
kubectl apply -f examples/nginx-demo-local.yaml

# 2. Verify
kubectl get all -n demo
curl -k https://demo.k3cluster.local

# 3. Update (edit manifest first)
kubectl apply -f examples/nginx-demo-local.yaml

# 4. Rollback if needed
kubectl rollout undo deployment/nginx-demo -n demo

# 5. Remove
kubectl delete -f examples/nginx-demo-local.yaml
kubectl delete namespace demo
```

### Helm Workflow

```bash
# 1. Deploy
kubectl create namespace demo
helm install nginx-demo ./examples/nginx-demo-helm --namespace demo

# 2. Verify
helm status nginx-demo --namespace demo
curl -k https://demo.k3cluster.local

# 3. Update
helm upgrade nginx-demo ./examples/nginx-demo-helm \
  --namespace demo \
  --set replicaCount=3

# 4. Rollback if needed
helm rollback nginx-demo --namespace demo

# 5. Remove
helm uninstall nginx-demo --namespace demo
kubectl delete namespace demo
```

## When to Use Each

### Use kubectl when:
- ✅ Learning Kubernetes
- ✅ Simple, one-off deployments
- ✅ Quick testing
- ✅ Working with individual resources
- ✅ You have simple, static configurations
- ✅ Direct control over exact manifests

### Use Helm when:
- ✅ Managing complex applications
- ✅ Need templating and variable substitution
- ✅ Deploying to multiple environments
- ✅ Need version control and rollback
- ✅ Sharing/distributing applications
- ✅ Need dependency management
- ✅ Want atomic deployments
- ✅ Managing application lifecycle

## Hybrid Approach

You can use both! Many teams use:

```bash
# Use Helm for application deployment
helm install myapp ./chart --namespace prod

# Use kubectl for inspection and debugging
kubectl get pods -n prod
kubectl logs -n prod pod/myapp-xyz
kubectl describe pod -n prod myapp-xyz

# Use kubectl for one-off tasks
kubectl run debug --image=busybox -it --rm -- sh
```

## Summary

**kubectl** is like using **direct SQL queries** - precise control, requires exact syntax.

**Helm** is like using an **ORM** - abstraction layer, easier to manage, but adds complexity.

Both are valuable tools. The choice depends on your use case:
- **Simple deployments**: kubectl
- **Complex applications**: Helm
- **Production environments**: Often Helm
- **Quick tests**: kubectl
- **Multiple environments**: Helm
