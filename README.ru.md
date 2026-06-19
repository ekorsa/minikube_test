# minikube_test

> [English version](README.md)

Учебный DevOps-проект: разворачивает FastAPI-приложение в локальном кластере Minikube с мониторингом и автоматической доставкой через GitHub Actions.

## Архитектура

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
  Helm Release: my-web   (Bitnami Nginx, 2 реплики, LoadBalancer)
        |
  Ingress (nginx):
        my-app.local     --> FastAPI :80
        grafana.local    --> Grafana :3000
```

## Стек

| Компонент | Технология | Версия |
|-----------|-----------|--------|
| Оркестратор | Minikube + kubectl | — |
| Пакетный менеджер | Helm | v3 |
| Приложение | FastAPI (Docker image из GHCR) | sha-26d54dd |
| Мониторинг | Prometheus (sidecar) | v2.45.0 |
| Дашборды | Grafana (sidecar) | v10.2.0 |
| База данных | PostgreSQL (Bitnami chart) | — |
| Веб-сервер | Nginx (Bitnami chart) | 2 реплики |
| Ingress | ingress-nginx | — |
| CI/CD | GitHub Actions (self-hosted runner) | — |

## Требования

- Minikube
- kubectl
- Helm 3
- Self-hosted GitHub Actions runner с меткой `local-kube`

## Быстрый старт

### 1. Запустить Minikube и включить ingress

```bash
minikube start
minikube addons enable ingress
```

### 2. Создать секрет для pull из GHCR

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token>
```

### 3. Развернуть PostgreSQL и Nginx

```bash
./deploy.sh
```

### 4. Развернуть основное приложение

```bash
helm upgrade --install my-release ./charts/my-devops-app
```

### 5. Открыть туннель для Ingress

```bash
minikube tunnel
```

### 6. Добавить записи в /etc/hosts

```
127.0.0.1  my-app.local
127.0.0.1  grafana.local
```

## Доступ к сервисам

| Сервис | URL |
|--------|-----|
| FastAPI приложение | http://my-app.local |
| Grafana | http://grafana.local |
| Prometheus | `kubectl port-forward` на порт 9090 |

## CI/CD

При каждом push в ветку `main` срабатывает GitHub Actions workflow (`.github/workflows/deploy.yml`):

1. Checkout репозитория с Helm-чартами
2. `helm upgrade --install` — обновление релиза в кластере
3. `kubectl rollout status` — ожидание успешного деплоя (таймаут 60 с)

Workflow выполняется на self-hosted раннере с меткой `local-kube`.

## Мониторинг

Prometheus и Grafana работают как sidecar-контейнеры внутри того же пода, что и FastAPI-приложение.

- **Prometheus** собирает метрики с FastAPI каждые 5 секунд, хранит данные 15 дней на PVC (2 Gi).
- **Grafana** поставляется с преднастроенным datasource (Prometheus) и готовым дашбордом FastAPI (`charts/my-devops-app/dashboards/fastapi.json`).

### Резервное копирование Prometheus

CronJob `prometheus-backup-job` каждые 30 минут архивирует базу Prometheus (TSDB) в `/data/prometheus-backups` на хост-машине Minikube:

```
*/30 * * * *  alpine tar -czf /backups/prom-db-backup-<timestamp>.tar.gz /prometheus
```

## Структура репозитория

```
.
├── charts/
│   └── my-devops-app/              # Helm chart основного приложения
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── dashboards/
│       │   └── fastapi.json        # Grafana dashboard
│       └── templates/
│           ├── deployment.yaml          # FastAPI + Prometheus + Grafana pod
│           ├── service.yaml             # ClusterIP: :80, :9090, :3000
│           ├── ingress.yaml             # my-app.local, grafana.local
│           ├── monitoring-configs.yaml  # ConfigMap: prometheus.yaml, datasource, provider
│           ├── prometheus-pvc.yaml      # PVC 2Gi для хранения метрик
│           ├── backup-cronjob.yaml      # Резервное копирование Prometheus
│           └── fastapi-dashboard-cm.yaml
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions CD pipeline
├── db-values.yaml             # Значения для Bitnami PostgreSQL
├── web-values.yaml            # Значения для Bitnami Nginx
└── deploy.sh                  # Скрипт деплоя PostgreSQL и Nginx
```
