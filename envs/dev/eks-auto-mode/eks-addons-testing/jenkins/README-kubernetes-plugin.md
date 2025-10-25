# Jenkins Kubernetes Plugin for Slave Management

This guide covers configuring Jenkins slaves using the Kubernetes plugin in an EKS Auto Mode cluster. The plugin enables dynamic provisioning of Kubernetes pods as Jenkins agents for distributed builds.

## Overview

The Jenkins Helm chart automatically installs and configures the [Kubernetes plugin](https://plugins.jenkins.io/kubernetes/) when `agent.enabled=true` is set. This plugin allows Jenkins to spawn Kubernetes pods as ephemeral slaves for running pipeline jobs, providing:

- **Dynamic Scaling**: Agents are created on-demand and terminated after job completion
- **Resource Efficiency**: No persistent EC2 instances needed for build workloads
- **Isolation**: Each job runs in its own pod with clean environment
- **EKS Integration**: Leverages EKS Auto Mode for automatic node scaling

## Prerequisites

- Jenkins deployed with Helm using `--set agent.enabled=true`
- Kubernetes plugin pre-installed (automatically handled by Helm)
- Appropriate RBAC permissions for pod creation in the namespace

## Configuration

### 1. Access Jenkins UI

Navigate to `http://jenkins.example.com` (or via ALB endpoint with host header).

### 2. Configure Kubernetes Cloud

1. Go to **Manage Jenkins** > **Manage Nodes and Clouds** > **Configure Clouds**
2. Click **Add a new cloud** > **Kubernetes**
3. Configure the following:

| Field | Value | Description |
|-------|-------|-------------|
| Name | `kubernetes` | Cloud identifier |
| Kubernetes URL | `https://kubernetes.default.svc.cluster.local` | In-cluster API server |
| Kubernetes Namespace | `default` | Namespace for agent pods |
| Credentials | `Jenkins (Service Account)` | Auto-configured by Helm |
| Jenkins URL | `http://jenkins.default.svc.cluster.local:8080` | Jenkins service URL |
| Jenkins tunnel | `jenkins-agent.default.svc.cluster.local:50000` | JNLP connection |

4. Test the connection to verify configuration

## Pod Templates

Pod templates define the specifications for agent pods. The plugin provides both default and custom templates.

### Default Pod Template

The Helm chart creates a default pod template with:
- **Name**: `default`
- **Namespace**: `default`
- **Labels**: `jenkins-agent`
- **Containers**: Single container with `jenkins/inbound-agent` image
- **Service Account**: Jenkins service account
- **Resource Limits**: Configurable via Helm values

### Custom Pod Templates

Create custom pod templates for specific build requirements:

1. In the Kubernetes cloud configuration, click **Add Pod Template**
2. Configure basic settings:

| Field | Description | Example |
|-------|-------------|---------|
| Name | Template identifier | `maven-build` |
| Namespace | Pod namespace | `default` |
| Labels | Node labels for job targeting | `maven java` |
| Usage | When to use this template | `Use this node as much as possible` |

### Container Templates

Each pod template can have multiple containers for complex builds:

#### Basic Container Configuration

| Field | Description | Example |
|-------|-------------|---------|
| Name | Container name | `maven` |
| Docker image | Container image | `maven:3.8-openjdk-11` |
| Working directory | Mount path | `/home/jenkins/agent` |
| Command to run | Entry point | `/bin/sh -c` |
| Arguments | Command args | `cat` |

#### Advanced Container Features

##### Resource Limits
```yaml
Resources:
  Requests:
    CPU: 500m
    Memory: 1Gi
  Limits:
    CPU: 2000m
    Memory: 4Gi
```

##### Environment Variables
```yaml
EnvVars:
  - Key: MAVEN_OPTS
    Value: -Xmx1024m
  - Key: JAVA_HOME
    Value: /usr/lib/jvm/java-11-openjdk-amd64
```

##### Volume Mounts
```yaml
VolumeMounts:
  - Name: maven-cache
    MountPath: /root/.m2
    ReadOnly: false
```

## Volumes

Configure persistent or ephemeral volumes for agent pods:

### Host Path Volumes
```yaml
Volumes:
  - HostPathVolume:
      HostPath: /tmp
      MountPath: /tmp
```

### Persistent Volume Claims
```yaml
Volumes:
  - PersistentVolumeClaim:
      ClaimName: jenkins-workspace
      MountPath: /workspace
```

### Config Maps and Secrets
```yaml
Volumes:
  - ConfigMapVolume:
      ConfigMapName: build-config
      MountPath: /etc/config
  - SecretVolume:
      SecretName: docker-registry-secret
      MountPath: /etc/secret
```

## Advanced Features

### Pod Template Inheritance

Create base templates and inherit settings:
- Use **Inherit from** field to reference parent template
- Override specific settings while inheriting others

### Node Selectors and Tolerations

Control pod scheduling on specific nodes:

```yaml
NodeSelector: 
  kubernetes.io/os: linux
  node-type: build-node

Tolerations:
  - Key: dedicated
    Operator: Equal
    Value: build
    Effect: NoSchedule
```

### Service Account Configuration

Use different service accounts for various build types:

```yaml
ServiceAccount: build-service-account
```

### YAML Configuration

For complex configurations, use YAML mode:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: slave
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi
  - name: docker
    image: docker:dind
    securityContext:
      privileged: true
```

### Custom Pod Specifications

Define complete pod specs for advanced scenarios:

```yaml
Custom pod template:
  spec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/arch
              operator: In
              values:
              - amd64
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
```

## Pipeline Integration

### Targeting Specific Templates

Use labels in pipeline scripts:

```groovy
node('maven java') {
    // This job will use pods with 'maven' and 'java' labels
    stage('Build') {
        sh 'mvn clean install'
    }
}
```

### Dynamic Agent Selection

```groovy
pipeline {
    agent {
        kubernetes {
            label 'maven-pod'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8-jdk-11
    command:
    - cat
    tty: true
"""
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean install'
            }
        }
    }
}
```

## Monitoring and Troubleshooting

### View Active Agents

- **Manage Jenkins** > **Manage Nodes and Clouds**
- Shows running pods and their status

### Pod Logs

```bash
kubectl logs -n default <pod-name>
```

### Common Issues

1. **Pods not starting**: Check RBAC permissions and resource quotas
2. **Image pull errors**: Verify image registry access and credentials
3. **JNLP connection failures**: Check Jenkins tunnel configuration
4. **Resource constraints**: Monitor pod resource usage and adjust limits

### Scaling Considerations

- **Pod Retention**: Configure pod retention time after job completion
- **Concurrent Builds**: Adjust max concurrent builds per template
- **Resource Management**: Set appropriate CPU/memory limits to prevent over-provisioning

## Security Considerations

- **Service Accounts**: Use minimal required permissions
- **Network Policies**: Restrict pod-to-pod communication
- **Image Security**: Use trusted base images and scan for vulnerabilities
- **Secret Management**: Avoid hardcoding secrets; use Kubernetes secrets

## Cost Optimization

- **Ephemeral Agents**: Pods are terminated after use, reducing costs
- **Spot Instances**: Configure node selectors for spot instance usage
- **Resource Limits**: Prevent resource waste with proper limits
- **Idle Timeout**: Set pod idle timeout to clean up unused agents

## Additional Resources

- [Kubernetes Plugin Documentation](https://plugins.jenkins.io/kubernetes/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Kubernetes Pod Specifications](https://kubernetes.io/docs/concepts/workloads/pods/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## Next Steps

1. Configure your first pod template
2. Test with a simple pipeline job
3. Customize templates for your specific build requirements
4. Monitor resource usage and adjust configurations as needed
