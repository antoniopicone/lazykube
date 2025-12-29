# Monitoring Stack - Quick Start Guide

Guida rapida per installare e utilizzare Prometheus + Grafana sul cluster K3s locale.

## Installazione Rapida

### 1. Prerequisiti

Assicurati che il cluster K3s sia installato:

```bash
export KUBECONFIG=~/.kube/k3s.dev-config.yml
kubectl get nodes
```

### 2. Installa lo Stack di Monitoring

```bash
cd /path/to/lazykube
ansible-playbook -i inventories/hosts.yml playbooks/install-monitoring-local.yml
```

L'installazione richiede circa 5-10 minuti.

### 3. Configura DNS

Aggiungi al file `/etc/hosts`:

```bash
sudo bash -c 'cat >> /etc/hosts << EOF
192.168.105.84  prometheus.k3s.dev
192.168.105.84  grafana.k3s.dev
192.168.105.84  alertmanager.k3s.dev
192.168.105.84  demo.k3s.dev
EOF'
```

### 4. Recupera la Password di Grafana

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

### 5. Accedi a Grafana

```bash
open https://grafana.k3s.dev
```

**Username**: `admin`
**Password**: [quella recuperata al passo 4]

---

## Deploy Applicazione Demo con Metriche

```bash
# Deploy nginx con Prometheus exporter
kubectl apply -f examples/nginx-demo-with-metrics.yaml

# Verifica che sia attivo
kubectl get pods -n demo
kubectl get servicemonitor -n demo

# Accedi all'applicazione
open https://demo.k3s.dev
```

---

## Verifica che Tutto Funzioni

### 1. Controlla i Target di Prometheus

```bash
open https://prometheus.k3s.dev/targets
```

Tutti i target dovrebbero essere **UP** (verdi).

### 2. Verifica le Metriche dell'Applicazione Demo

In Prometheus, esegui questa query:

```promql
nginx_connections_active
```

Dovresti vedere le metriche dei container nginx.

### 3. Visualizza le Dashboard in Grafana

In Grafana:
1. Vai su **Dashboards** → **Browse**
2. Apri **K3s Cluster Overview**
3. Controlla che i grafici mostrino dati

---

## Query Prometheus Utili

```promql
# CPU usage per node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count
count(kube_pod_info) by (namespace)

# Nginx requests per second
rate(nginx_http_requests_total[5m])

# Pod restarts
rate(kube_pod_container_status_restarts_total[1h])
```

---

## Comandi Utili

```bash
# Stato dei pod di monitoring
kubectl get pods -n monitoring

# Stato delle metriche raccolte
kubectl get servicemonitor -A

# Log di Prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f

# Log di Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Port-forward locale (senza Ingress)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

---

## Importare Certificate CA

Per evitare avvisi SSL nel browser:

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.kube/k3s-local-ca.crt
```

---

## Dashboard Consigliate da Importare

1. **Kubernetes Cluster (Prometheus)** - ID: 7249
2. **Node Exporter Full** - ID: 1860
3. **Kubernetes API Server** - ID: 15759
4. **Kubernetes Networking Cluster** - ID: 13770

Per importare:
1. Vai su Grafana → **+** → **Import**
2. Inserisci l'ID della dashboard
3. Seleziona datasource **Prometheus**
4. Click **Import**

---

## Troubleshooting Rapido

### Pod non parte

```bash
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

### Grafana non mostra dati

Verifica che il datasource Prometheus sia configurato:
- **Configuration** → **Data sources** → **Prometheus**
- URL dovrebbe essere: `http://kube-prometheus-stack-prometheus:9090`

### Target Prometheus DOWN

```bash
# Verifica i ServiceMonitors
kubectl get servicemonitor -A

# Controlla i selettori
kubectl get servicemonitor -n demo nginx-demo -o yaml
```

---

## Risorse

- [Documentazione Completa](../docs/MONITORING.md)
- [Prometheus Queries](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

---

## URL Rapidi

- **Grafana**: https://grafana.k3s.dev
- **Prometheus**: https://prometheus.k3s.dev
- **AlertManager**: https://alertmanager.k3s.dev
- **Traefik Dashboard**: https://traefik.k3s.dev/dashboard/
- **Demo App**: https://demo.k3s.dev

---

Buon monitoring! 📊
