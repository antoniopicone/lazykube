# Monitoring Stack - Prometheus + Grafana

Guida completa per installare e utilizzare lo stack di monitoring basato su Prometheus e Grafana sul cluster K3s locale.

## Indice

- [Panoramica](#panoramica)
- [Componenti](#componenti)
- [Prerequisiti](#prerequisiti)
- [Installazione](#installazione)
- [Configurazione DNS](#configurazione-dns)
- [Accesso ai Servizi](#accesso-ai-servizi)
- [Dashboard Grafana](#dashboard-grafana)
- [Metriche Disponibili](#metriche-disponibili)
- [ServiceMonitor Personalizzati](#servicemonitor-personalizzati)
- [Troubleshooting](#troubleshooting)

---

## Panoramica

Lo stack di monitoring include:

- **Prometheus**: Sistema di monitoring e time-series database
- **Grafana**: Piattaforma di visualizzazione e analisi
- **AlertManager**: Gestione degli alert
- **Node Exporter**: Metriche dei nodi del cluster
- **kube-state-metrics**: Metriche sugli oggetti Kubernetes

Tutti i componenti sono installati nel namespace `monitoring` e sono accessibili tramite Ingress con certificati self-signed.

---

## Componenti

### Prometheus Operator

L'installazione utilizza il chart Helm `kube-prometheus-stack` che include:

- Prometheus Operator per la gestione delle risorse Prometheus
- Prometheus server con storage persistente (10GB)
- AlertManager per la gestione degli alert
- Grafana con dashboard pre-configurate
- ServiceMonitors per raccogliere metriche da vari componenti

### Metriche Raccolte

Il sistema raccoglie automaticamente metriche da:

- **API Server**: Metriche dell'API di Kubernetes
- **Kubelet**: Metriche dei nodi (CPU, memoria, disco, rete)
- **cAdvisor**: Metriche dei container
- **Node Exporter**: Metriche del sistema operativo
- **kube-state-metrics**: Stato degli oggetti K8s (Pods, Deployments, Services, ecc.)
- **Traefik**: Metriche dell'Ingress Controller
- **Custom Applications**: Tramite ServiceMonitors personalizzati

---

## Prerequisiti

Prima di installare lo stack di monitoring, assicurati che:

1. Il cluster K3s sia installato e funzionante
2. Traefik Ingress Controller sia installato
3. cert-manager sia installato per i certificati HTTPS
4. MetalLB sia configurato per i LoadBalancer
5. HAProxy sia configurato come entry point

```bash
# Verifica che il cluster sia funzionante
export KUBECONFIG=~/.kube/k3s.dev-config.yml
kubectl get nodes
kubectl get pods -n traefik
kubectl get pods -n cert-manager
```

---

## Installazione

### Passo 1: Esegui il Playbook

```bash
cd /path/to/lazykube

# Installa lo stack di monitoring
ansible-playbook -i inventories/hosts.yml playbooks/install-monitoring-local.yml
```

### Passo 2: Verifica l'Installazione

```bash
# Controlla i pod nel namespace monitoring
kubectl get pods -n monitoring

# Attendi che tutti i pod siano Running
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/part-of=kube-prometheus-stack -n monitoring --timeout=5m
```

### Passo 3: Recupera la Password di Grafana

```bash
# Recupera la password admin di Grafana
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

---

## Configurazione DNS

Aggiungi le seguenti entry al file `/etc/hosts` del tuo Mac:

```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# K3s Monitoring Stack (via HAProxy)
192.168.105.84  prometheus.k3s.dev
192.168.105.84  grafana.k3s.dev
192.168.105.84  alertmanager.k3s.dev
EOF'
```

**Nota**: Sostituisci `192.168.105.84` con l'IP del tuo HAProxy se diverso.

---

## Accesso ai Servizi

### Grafana

```bash
# Apri Grafana nel browser
open https://grafana.k3s.dev

# Credenziali
Username: admin
Password: [recuperata con il comando sopra]
```

### Prometheus

```bash
# Apri Prometheus UI
open https://prometheus.k3s.dev

# Verifica i target attivi
open https://prometheus.k3s.dev/targets
```

### AlertManager

```bash
# Apri AlertManager UI
open https://alertmanager.k3s.dev
```

### Importare il Certificato CA

Per evitare gli avvisi di sicurezza del browser:

```bash
# Importa il certificato CA nel sistema
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/.kube/k3s-local-ca.crt
```

---

## Dashboard Grafana

### Dashboard Pre-installate

Grafana include diverse dashboard pre-configurate:

1. **K3s Cluster Overview** (custom)
   - Panoramica del cluster
   - Numero di nodi e pod
   - CPU e memoria aggregati

2. **Kubernetes / Views / Global** (ID: 15757)
   - Vista globale del cluster
   - Utilizzo risorse per namespace
   - Stato dei workload

3. **Node Exporter Full** (ID: 1860)
   - Metriche dettagliate dei nodi
   - CPU, memoria, disco, rete
   - I/O e file system

4. **Kubernetes / Views / Pods** (ID: 6417)
   - Stato dei pod
   - Restart count
   - Resource limits vs usage

5. **Nginx Demo Application** (custom)
   - Metriche specifiche dell'applicazione demo
   - Request rate
   - Memory e CPU per pod

### Importare Dashboard Aggiuntive

Puoi importare dashboard dalla [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/):

1. Vai su Grafana → Dashboard → Import
2. Inserisci l'ID della dashboard (es: 7249 per Kubernetes Cluster)
3. Seleziona "Prometheus" come datasource
4. Clicca su "Import"

Dashboard consigliate:
- **7249**: Kubernetes Cluster (Prometheus)
- **15759**: Kubernetes / System / API Server
- **13770**: Kubernetes / Networking / Cluster
- **747**: Kubernetes Deployment Statefulset Daemonset

---

## Metriche Disponibili

### Query Prometheus Utili

```promql
# CPU usage per node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count per namespace
count(kube_pod_info) by (namespace)

# Container restarts
rate(kube_pod_container_status_restarts_total[1h])

# Persistent Volume usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100

# HTTP request rate (Traefik)
rate(traefik_service_requests_total[5m])
```

### Metriche delle Applicazioni

Per esporre metriche personalizzate dalle tue applicazioni:

1. Implementa un endpoint `/metrics` in formato Prometheus
2. Crea un ServiceMonitor per raccogliere le metriche
3. Verifica che le metriche siano visibili in Prometheus

---

## ServiceMonitor Personalizzati

### Esempio: Monitorare un'Applicazione Custom

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
  labels:
    app: my-app
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Nginx con Prometheus Exporter

Vedi l'esempio completo in [`examples/nginx-demo-with-metrics.yaml`](../examples/nginx-demo-with-metrics.yaml):

```bash
# Deploy dell'applicazione demo con metriche
kubectl apply -f examples/nginx-demo-with-metrics.yaml

# Verifica che il ServiceMonitor sia attivo
kubectl get servicemonitor -n demo

# Controlla in Prometheus
open https://prometheus.k3s.dev/targets
```

---

## Alert e Notifiche

### Alert Pre-configurati

Il sistema include alert predefiniti per:

- **Node/Pod Down**: Nodi o pod non disponibili
- **High CPU/Memory**: Utilizzo risorse superiore all'80%
- **Disk Space**: Spazio disco inferiore al 10%
- **Pod Restart Loop**: Pod con restart frequenti
- **API Server Errors**: Errori nell'API Server

### Visualizzare gli Alert

```bash
# Apri AlertManager
open https://alertmanager.k3s.dev

# Query alert attivi in Prometheus
open https://prometheus.k3s.dev/alerts
```

### Configurare Notifiche

Per configurare notifiche (email, Slack, PagerDuty, ecc.), modifica il file:

```bash
# Edita la configurazione di AlertManager
kubectl edit configmap -n monitoring alertmanager-kube-prometheus-stack-alertmanager
```

Esempio configurazione per Slack:

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#k8s-alerts'
        title: 'Kubernetes Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

---

## Configurazione Avanzata

### Aumentare la Retention di Prometheus

```bash
# Edita i valori Helm
kubectl edit prometheuses.monitoring.coreos.com -n monitoring kube-prometheus-stack-prometheus
```

Modifica la sezione `spec`:

```yaml
spec:
  retention: 30d  # Da 7d a 30d
  retentionSize: 50GB  # Da 10GB a 50GB
```

### Aggiungere Storage Persistente

Lo storage persistente è già configurato di default:

- Prometheus: 10GB
- Grafana: 5GB
- AlertManager: 2GB

Per modificare le dimensioni:

```bash
# Edita il PVC
kubectl edit pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
```

### Configurare Remote Write

Per inviare metriche a un Prometheus remoto o a servizi cloud:

```yaml
# Aggiungi alla configurazione di Prometheus
remoteWrite:
  - url: "https://remote-prometheus.example.com/api/v1/write"
    basicAuth:
      username:
        name: remote-secret
        key: username
      password:
        name: remote-secret
        key: password
```

---

## Troubleshooting

### I Pod non si avviano

```bash
# Verifica i pod
kubectl get pods -n monitoring

# Descrivi il pod con problemi
kubectl describe pod <pod-name> -n monitoring

# Controlla i log
kubectl logs -n monitoring <pod-name>
```

### Prometheus non Raccoglie Metriche

```bash
# Verifica i ServiceMonitors
kubectl get servicemonitors -A

# Controlla la configurazione di Prometheus
kubectl get prometheus -n monitoring -o yaml

# Verifica i target in Prometheus UI
open https://prometheus.k3s.dev/targets
```

### Grafana non Mostra Dati

```bash
# Verifica che il datasource Prometheus sia configurato
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://localhost:3000/api/datasources

# Testa la connettività a Prometheus
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  curl -s http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=up
```

### Certificati HTTPS non Funzionano

```bash
# Verifica che cert-manager sia installato
kubectl get pods -n cert-manager

# Controlla il certificato
kubectl get certificate -n monitoring

# Verifica il ClusterIssuer
kubectl get clusterissuer ca-issuer -o yaml
```

### Problemi di Performance

```bash
# Riduce la frequenza di scraping
kubectl edit prometheus -n monitoring kube-prometheus-stack-prometheus

# Modifica l'intervallo globale
spec:
  scrapeInterval: 60s  # Da 30s a 60s
```

---

## Disinstallazione

Per rimuovere completamente lo stack di monitoring:

```bash
# Rimuovi il release Helm
helm uninstall -n monitoring kube-prometheus-stack

# Rimuovi il namespace
kubectl delete namespace monitoring

# Rimuovi i CRD (opzionale - attenzione!)
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
```

---

## Risorse Utili

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)

---

## Note di Sicurezza

- La password di Grafana di default è `admin` - **CAMBIARLA IMMEDIATAMENTE** in produzione
- I certificati sono self-signed - utilizzare certificati validi in produzione
- AlertManager non ha autenticazione di default - configurarla se esposto pubblicamente
- Limita l'accesso ai servizi di monitoring tramite Network Policies se necessario

---

## Supporto

Per problemi o domande:

1. Controlla la sezione [Troubleshooting](#troubleshooting)
2. Verifica i log dei pod con problemi
3. Consulta la documentazione ufficiale dei componenti
4. Apri un issue nel repository del progetto

---

**Ultimo aggiornamento**: Novembre 2025
**Versione Stack**: Prometheus 2.x + Grafana 10.x
