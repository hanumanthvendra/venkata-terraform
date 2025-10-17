# Setting Up Prometheus Monitoring and Custom HPA for a Flask App on EKS

## Introduction

In the world of Kubernetes, monitoring and autoscaling are crucial for maintaining application performance and cost efficiency. Recently, I worked on integrating Prometheus with a custom Python Flask application called Flamecraft, deployed on Amazon EKS. The goal was to enable Horizontal Pod Autoscaling (HPA) based on custom metrics from the app's `/metrics` endpoint. This post walks through the setup, customizations, and the reasoning behind the changes we made.

## Prometheus Installation on EKS

Prometheus is a powerful open-source monitoring and alerting toolkit. On Amazon EKS, we can install it using the EKS add-ons or Helm charts. In our case, Prometheus was installed in the `monitoring` namespace using the kube-prometheus-stack Helm chart, which bundles Prometheus, Grafana, and Alertmanager.

### Installation Steps

1. **Add the Prometheus Community Helm Repository:**
   ```
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   ```

2. **Install the kube-prometheus-stack:**
   ```
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace \
     --set prometheus.service.type=ClusterIP \
     --set grafana.service.type=ClusterIP
   ```

This setup provides:
- Prometheus server for metrics collection
- Grafana for visualization
- Alertmanager for alerting
- Node Exporter for system metrics
- Kube State Metrics for Kubernetes object metrics

### Key Components

- **Prometheus Server:** Scrapes metrics from configured targets.
- **ServiceMonitors:** Custom resources that tell Prometheus how to scrape services.
- **Prometheus Adapter:** Exposes Prometheus metrics as Kubernetes custom metrics for HPA.

## Flamecraft App Customization

Flamecraft is a simple Python Flask application that exposes a REST API for employee management. To integrate with Prometheus, we customized it to expose metrics using the `prometheus_flask_exporter` library.

### Application Structure

The app uses:
- Flask for the web framework
- Flask-RESTful for API endpoints
- Prometheus Flask Exporter for automatic metrics collection

### Key Customizations

1. **Metrics Integration:**
   ```python
   from prometheus_flask_exporter import PrometheusMetrics

   app = Flask(__name__)
   metrics = PrometheusMetrics(app)
   ```

2. **Endpoints:**
   - `/employees` (GET/POST): Manage employees
   - `/health`: Health check
   - `/ready`: Readiness check
   - `/metrics`: Prometheus metrics endpoint (automatically added by the exporter)

3. **Docker Configuration:**
   - Multi-stage build for security
   - Non-root user execution
   - Read-only root filesystem

4. **Kubernetes Deployment:**
   - Deployed in `dev` namespace
   - Service exposing port 80 (targeting container port 5500)
   - Liveness and readiness probes

## Custom Changes Made

Throughout the setup, we encountered issues with HPA not scaling based on custom metrics. Here are the key changes we implemented:

### 1. ServiceMonitor Creation

**File:** `servicemonitor-flamecraft.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flamecraft-app
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames: ["dev"]
  selector:
    matchLabels:
      app: flamecraft-app
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

**What it does:** Tells Prometheus to scrape the `/metrics` endpoint from the Flamecraft service every 15 seconds.

### 2. Prometheus Adapter Configuration Update

**File:** `config.yaml` (merged into `prometheus-adapter` ConfigMap)

```yaml
rules:
- metricsQuery: |
    sum by (<<.GroupBy>>)(
      rate(http_requests_total{<<.LabelMatchers>>}[2m])
    )
  name:
    as: http_requests_per_second
  resources:
    overrides:
      namespace:
        resource: namespace
      pod:
        resource: pod
  seriesQuery: http_requests_total{namespace!="",pod!=""}
- seriesQuery: '{__name__="flask_http_request_total",namespace="dev",pod!=""}'
  resources:
    overrides:
      namespace:
        resource: namespace
      pod:
        resource: pod
  name:
    matches: ^flask_http_request_total$
    as: http_requests_per_second
  metricsQuery: sum(rate(flask_http_request_total{<<.LabelMatchers>>}[5m])) by (<<.GroupBy>>)
```

**What it does:** Defines rules for the Prometheus Adapter to expose `http_requests_per_second` as a custom metric for HPA.

### 3. HPA Configuration

**File:** `flamecraft-app/flamecraft-hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: flamecraft-app-hpa
  namespace: dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: flamecraft-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: 5
```

**What it does:** Configures HPA to scale based on CPU, memory, and custom `http_requests_per_second` metric.

## Why These Changes Were Needed

### The Problem

Initially, the HPA couldn't scale the Flamecraft deployment because it couldn't fetch the `http_requests_per_second` metric. The error was: "unable to get metric http_requests_per_second: unable to fetch metrics from custom metrics API: the server could not find the metric http_requests_per_second for pods".

### Root Cause Analysis

1. **Missing Scraping Configuration:** Prometheus wasn't configured to scrape metrics from the Flamecraft app. While the app exposed `/metrics`, Prometheus didn't know about it.

2. **Incorrect Adapter Configuration:** The Prometheus Adapter's ConfigMap only had generic rules and didn't include specific rules for the Flask app's metrics.

3. **Service vs. Pod Metrics:** The original HPA configuration assumed service-level metrics, but we needed pod-level metrics for accurate per-pod scaling.

### Why ServiceMonitor?

- **Purpose:** ServiceMonitors are the standard way to tell Prometheus about services to scrape in Kubernetes environments.
- **Namespace Isolation:** Allows scraping services in the `dev` namespace from the `monitoring` namespace.
- **Label Matching:** Uses the `release: prometheus` label to match the Prometheus instance's serviceMonitorSelector.

### Why Adapter Configuration Update?

- **Custom Metrics Exposure:** The adapter needs specific rules to transform Prometheus metrics into Kubernetes custom metrics.
- **Pod-Level Metrics:** HPA works with pod-level metrics, so we configured the adapter to expose metrics per pod.
- **Rate Calculation:** The rule calculates the rate of `flask_http_request_total` over 5 minutes to get requests per second.

### Why HPA Changes?

- **Multi-Metric Scaling:** Combines resource-based (CPU/memory) and custom metrics for comprehensive autoscaling.
- **Target Values:** Set reasonable thresholds (5 requests/second average) to trigger scaling.
- **Behavior Tuning:** Configured scale-up and scale-down policies for smooth scaling.

## Verification and Results

After implementing these changes:

1. **Prometheus Scraping:** Confirmed Flamecraft metrics appear in Prometheus UI.
2. **Custom Metrics API:** Verified `http_requests_per_second` is available via `kubectl get --raw`.
3. **HPA Functionality:** HPA successfully scaled from 3 to 9 replicas based on request load.

### Validating from Prometheus and Grafana

You can (and should) validate the setup from Prometheus and Grafana UIs:

#### Prometheus/Grafana Queries

**Per-pod RPS (what HPA uses under the hood):**
```
sum by (pod) (
  rate(http_requests_total{namespace="dev", app="flamecraft-app"}[2m])
)
```

**Average RPS across pods (to compare with HPA target=5):**
```
avg(
  sum by (pod) (
    rate(http_requests_total{namespace="dev", app="flamecraft-app"}[2m])
  )
)
```

Note: You won't see `http_requests_per_second` in Prometheus—that name exists only in the adapter. In Prom/Grafana, query the source metric (`http_requests_total` or your actual counter like `flask_http_request_total`).

#### Nice Grafana Panels

- **Per-pod RPS time series:** Use the first query; Legend: `{{pod}}`.
- **SingleStat/Gauge for average RPS:** Use the second query; compare mentally to HPA target.

### Exposing Prometheus/Grafana via Ingress

Ingress backends must be in the same namespace as the backend Service. Since Prometheus/Grafana are in `monitoring`, create Ingresses there:

#### Option A (Recommended): Ingress in monitoring

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx   # or your class
spec:
  rules:
  - host: prometheus.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
```

Do the same for Grafana (usually service `kube-prometheus-stack-grafana` on port 80/3000).

#### Option B: Port-forward (Quick Check)

```bash
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000
```

#### Option C: Cross-namespace Indirection

If you must keep Ingress in `default`, create a same-namespace Service of type `ExternalName` pointing to `prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local`, then route the Ingress to that Service.

### Quick Sanity Checklist

- Your Ingress controller watches the `monitoring` namespace.
- DNS for your hostnames points to the ingress controller.
- In Prometheus, the queries above return sensible values for `app=flamecraft-app`.
- In HPA: `kubectl -n dev describe hpa flamecraft-app-hpa` shows the custom metric current/target.

## Conclusion

Setting up custom metrics-based HPA requires careful integration between your application, Prometheus, and Kubernetes. The key lessons:

- Ensure Prometheus can scrape your app's metrics
- Configure the adapter to expose the right metrics
- Use appropriate HPA configuration for your scaling needs

This setup provides robust autoscaling for the Flamecraft app, ensuring it can handle varying loads efficiently while maintaining performance and cost optimization.

If you're implementing similar setups, remember that debugging often involves checking each component in the chain: app metrics → Prometheus scraping → adapter configuration → HPA rules.

---

*This post is based on a real-world implementation on Amazon EKS. Code snippets are simplified for clarity.*
