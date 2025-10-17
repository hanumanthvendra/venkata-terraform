# HPA Configuration Guide: Resource vs Pods Metrics

## Overview
Horizontal Pod Autoscaler (HPA) in Kubernetes can scale deployments based on different types of metrics. This guide explains how to configure HPA for both built-in Resource metrics (CPU/Memory) and custom Pods metrics (like `http_requests_per_second`).

## Metric Types

### 1. Resource Metrics
- **Type**: `Resource`
- **Description**: Built-in metrics provided by Kubernetes (CPU, Memory)
- **Target**: Utilization percentage (e.g., 70% CPU)
- **Pros**: Simple, no additional setup required
- **Cons**: Limited to CPU/Memory, may not reflect application-specific load

### 2. Pods Metrics
- **Type**: `Pods`
- **Description**: Custom metrics per pod, exposed via Prometheus Adapter
- **Target**: Average value per pod (e.g., 5 requests/second)
- **Pros**: Application-specific scaling, more precise
- **Cons**: Requires Prometheus, custom metrics setup

## Current Configuration
The flamecraft-app HPA currently uses Resource metrics:

```yaml
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
```

## Adding Custom Pods Metrics
To add `http_requests_per_second` scaling:

1. **Ensure Prometheus Adapter is configured** with custom metric rules
2. **Update HPA spec** to include Pods metric:

```yaml
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

## Scaling with Both Metrics
HPA can use multiple metrics simultaneously. Scaling occurs when **any** metric exceeds its target. For example:
- Scale up if CPU > 50% OR Memory > 70% OR Requests > 5/sec per pod
- Scale down only when **all** metrics are below targets

## Steps to Update HPA

1. **Backup current HPA**:
   ```bash
   kubectl get hpa flamecraft-app-hpa -n dev -o yaml > hpa-backup.yaml
   ```

2. **Edit HPA** to add Pods metric alongside Resource metrics

3. **Apply changes**:
   ```bash
   kubectl apply -f flamecraft-app/flamecraft-hpa.yaml
   ```

4. **Verify**:
   ```bash
   kubectl get hpa -n dev
   kubectl describe hpa flamecraft-app-hpa -n dev
   ```

## Testing
- Deploy load generator to increase requests
- Monitor HPA targets: `kubectl get hpa -n dev -w`
- Check pod scaling: `kubectl get pods -n dev -l app=flamecraft-app`

## Troubleshooting
- Ensure Prometheus Adapter is running and configured
- Check custom metrics availability: `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"`
- Verify metric names match Prometheus rules
