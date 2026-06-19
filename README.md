# minikube_test

> [Русская версия](README.ru.md)

A learning DevOps project that deploys a FastAPI application to a local Minikube cluster with monitoring and automated delivery via GitHub Actions.

## Architecture

```
GitHub Actions (CD)
        |
        v
  Helm Chart: my-devops-app
        |
        +-- Pod: FastAPI (ghcr.io/ekorsa/fastapi_docker_test) :8000
        |     |
        |     +-- Sidecar: Prometheus v2.45.0 :9090  <-- PVC 2Gi
        |     +-- Sidecar: Grafana v10.2.0    :3000
        |
  Helm Release: my-db    (Bitnami PostgreSQL)
  Helm Release: my-web   (Bitnami Nginx, 2 replicas, LoadBalancer)
        |
  Ingress (nginx):
        my-app.local     --> FastAPI :80
        grafana.local    --> Grafana :3000
```

## Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Orchestrator | Minikube + kubectl | — |
| Package manager | Helm | v3 |
| Application | FastAPI (Docker image from GHCR) | sha-26d54dd |
| Metrics | Prometheus (sidecar) | v2.45.0 |
| Dashboards | Grafana (sidecar) | v10.2.0 |
| Database | PostgreSQL (Bitnami chart) | — |
| Web server | Nginx (Bitnami chart) | 2 replicas |
| Ingress | ingress-nginx | — |
| CI/CD | GitHub Actions (self-hosted runner) | — |

## Requirements

- Minikube
- kubectl
- Helm 3
- Self-hosted GitHub Actions runner labelled `local-kube`

## Quick Start

### 1. Start Minikube and enable ingress

```bash
minikube start
minikube addons enable ingress
```

### 2. Create a secret for pulling from GHCR

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token>
```

### 3. Deploy PostgreSQL and Nginx

```bash
./deploy.sh
```

### 4. Deploy the main application

```bash
helm upgrade --install my-release ./charts/my-devops-app
```

### 5. Open a tunnel for Ingress

```bash
minikube tunnel
```

### 6. Add entries to /etc/hosts

```
127.0.0.1  my-app.local
127.0.0.1  grafana.local
```

## Accessing Services

| Service | URL |
|---------|-----|
| FastAPI application | http://my-app.local |
| Grafana | http://grafana.local |
| Prometheus | `kubectl port-forward` on port 9090 |

## CI/CD

Every push to the `main` branch triggers the GitHub Actions workflow (`.github/workflows/deploy.yml`):

1. Checkout the repository with Helm charts
2. `helm upgrade --install` — update the release in the cluster
3. `kubectl rollout status` — wait for successful deployment (60 s timeout)

The workflow runs on a self-hosted runner labelled `local-kube`.

## Monitoring

Prometheus and Grafana run as sidecar containers inside the same pod as the FastAPI application.

- **Prometheus** scrapes metrics from FastAPI every 5 seconds and retains data for 15 days on a 2 Gi PVC.
- **Grafana** ships with a pre-configured Prometheus datasource and a ready-made FastAPI dashboard (`charts/my-devops-app/dashboards/fastapi.json`).

### Prometheus Backup

The `prometheus-backup-job` CronJob archives the Prometheus TSDB every 30 minutes to `/data/prometheus-backups` on the Minikube host:

```
*/30 * * * *  alpine tar -czf /backups/prom-db-backup-<timestamp>.tar.gz /prometheus
```

## Repository Structure

```
.
├── charts/
│   └── my-devops-app/              # Helm chart for the main application
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── dashboards/
│       │   └── fastapi.json        # Grafana dashboard
│       └── templates/
│           ├── deployment.yaml          # FastAPI + Prometheus + Grafana pod
│           ├── service.yaml             # ClusterIP: :80, :9090, :3000
│           ├── ingress.yaml             # my-app.local, grafana.local
│           ├── monitoring-configs.yaml  # ConfigMap: prometheus.yaml, datasource, provider
│           ├── prometheus-pvc.yaml      # 2Gi PVC for metrics storage
│           ├── backup-cronjob.yaml      # Prometheus backup job
│           └── fastapi-dashboard-cm.yaml
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions CD pipeline
├── db-values.yaml             # Values for Bitnami PostgreSQL
├── web-values.yaml            # Values for Bitnami Nginx
└── deploy.sh                  # Script to deploy PostgreSQL and Nginx
```
