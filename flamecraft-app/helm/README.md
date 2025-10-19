# Flamecraft App Helm Chart

This Helm chart deploys the Flamecraft Flask REST API application to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `flamecraft-app`:

```bash
helm install flamecraft-app ./helm
```

The command deploys the Flamecraft app on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `flamecraft-app` deployment:

```bash
helm uninstall flamecraft-app
```

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
|---------------------------|-------------------------------------------------|-------|
| `namespace`               | Namespace to deploy the application             | `dev` |
| `replicaCount`            | Number of replicas                              | `3`   |

### Image parameters

| Name                 | Description                                                  | Value                                    |
|----------------------|--------------------------------------------------------------|------------------------------------------|
| `image.repository`   | Flamecraft app image repository                              | `public.ecr.aws/e9s5a3s2/flamecraft`     |
| `image.pullPolicy`   | Image pull policy                                            | `Always`                                |
| `image.tag`          | Image tag (overrides the image tag whose default is the chart appVersion) | `latest` |

### Service parameters

| Name                  | Description                                   | Value       |
|-----------------------|-----------------------------------------------|-------------|
| `service.type`        | Kubernetes service type                       | `ClusterIP` |
| `service.port`        | Service port                                  | `80`        |

### Autoscaling parameters

| Name                                        | Description                                            | Value  |
|---------------------------------------------|--------------------------------------------------------|--------|
| `autoscaling.enabled`                       | Enable autoscaling                                     | `true` |
| `autoscaling.minReplicas`                   | Minimum number of replicas                             | `3`    |
| `autoscaling.maxReplicas`                   | Maximum number of replicas                             | `20`   |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage                       | `50`   |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage                | `70`   |

### Resource parameters

| Name                     | Description                | Value          |
|--------------------------|----------------------------|----------------|
| `resources.requests.cpu` | CPU request                | `70m`          |
| `resources.requests.memory` | Memory request            | `70Mi`         |
| `resources.limits.cpu`   | CPU limit                  | `100m`         |
| `resources.limits.memory`| Memory limit               | `100Mi`        |

### Security parameters

| Name                              | Description                          | Value     |
|-----------------------------------|--------------------------------------|-----------|
| `securityContext.runAsNonRoot`    | Run as non-root user                 | `true`    |
| `securityContext.runAsUser`       | User ID                              | `10000`   |
| `securityContext.runAsGroup`      | Group ID                             | `10000`   |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem       | `true`    |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation     | `false`   |
| `securityContext.capabilities.drop`| Drop capabilities                   | `["ALL"]` |

### Image pull secrets

| Name                | Description                      | Value               |
|---------------------|----------------------------------|---------------------|
| `imagePullSecrets`  | Image pull secrets               | `["regcred"]`       |

## Configuration and Installation Details

The Flamecraft app is a Flask-based REST API that provides employee management functionality. It includes:

- RESTful endpoints for employee CRUD operations
- Prometheus metrics integration
- Health and readiness probes
- Security headers and input validation
- Horizontal Pod Autoscaling based on CPU, memory, and custom metrics

The chart deploys:
- A Deployment with configurable replicas
- A Service exposing the application
- An optional HorizontalPodAutoscaler for autoscaling

## Values

For detailed configuration options, see the `values.yaml` file in the chart directory.
