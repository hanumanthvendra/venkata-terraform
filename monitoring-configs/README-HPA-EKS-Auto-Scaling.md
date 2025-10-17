# HPA + EKS Auto Mode Auto-Scaling Presentation

This repository contains a comprehensive presentation and demonstration of Kubernetes auto-scaling using both Horizontal Pod Autoscaler (HPA) and EKS Auto Mode for complete pod and node scaling.

## 📁 Files Overview

### Core Configuration Files
- **`deployment.yaml`** - Nginx application deployment with resource constraints
- **`hpa.yaml`** - Horizontal Pod Autoscaler configuration
- **`metrics-server.yaml`** - Metrics Server for resource monitoring
- **`load-generator.yaml`** - Load testing pod configuration

### Presentation Materials
- **`HPA-EKS-Auto-Mode-Presentation.md`** - Complete presentation with explanations, configurations, and results
- **`generate-scaling-demo.sh`** - Automated demonstration script

## 🎯 What This Demonstrates

### 1. **Pod Auto-Scaling (HPA)**
- Monitors CPU and memory utilization
- Scales pods from 3 to 10 replicas based on 70% thresholds
- Smart scaling policies to prevent rapid scaling

### 2. **Node Auto-Scaling (EKS Auto Mode)**
- Automatically provisions new EC2 instances when pod capacity is reached
- Distributes pods across multiple nodes
- Zero manual intervention required

### 3. **Combined Scaling Architecture**
- HPA handles pod scaling based on resource metrics
- EKS Auto Mode handles node scaling based on pod scheduling needs
- Seamless integration for complete auto-scaling solution

## 🚀 Quick Start

### Prerequisites
- EKS cluster with Auto Mode enabled
- kubectl configured to access the cluster
- AWS CLI configured

### 1. Deploy the Components
```bash
# Apply all configurations
kubectl apply -f metrics-server.yaml
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml
```

### 2. Verify Setup
```bash
# Check Metrics Server
kubectl get pods -n kube-system | grep metrics-server

# Check HPA status
kubectl get hpa

# Check resource metrics
kubectl top nodes
kubectl top pods
```

### 3. Run the Demonstration
```bash
# Make script executable
chmod +x generate-scaling-demo.sh

# Run the automated demonstration
./generate-scaling-demo.sh
```

## 📊 Expected Results

### Before Scaling
```
Nodes: 1
Pods: 3 replicas
HPA: cpu: 0%/70%, memory: 0%/70%
```

### After Load Testing
```
Nodes: 2 (EKS Auto Mode added a new node)
Pods: 3 replicas (distributed across nodes)
HPA: Monitoring resource utilization
```

## 📖 Presentation Structure

The `HPA-EKS-Auto-Mode-Presentation.md` includes:

1. **Introduction** - Overview of HPA and EKS Auto Mode
2. **Infrastructure Setup** - EKS cluster configuration
3. **Component Configurations** - All YAML files explained
4. **Step-by-Step Demonstration** - How scaling works
5. **Real Results** - Screenshots and outputs from testing
6. **Architecture Overview** - How components work together
7. **Best Practices** - Optimization tips
8. **Troubleshooting** - Common issues and solutions

## 🔧 Key Features Demonstrated

- ✅ **Automatic Pod Scaling** based on CPU/memory thresholds
- ✅ **Automatic Node Provisioning** when capacity is reached
- ✅ **Resource Optimization** across pods and nodes
- ✅ **Zero Manual Intervention** for scaling decisions
- ✅ **Cost Efficiency** through intelligent resource allocation

## 📈 Monitoring Commands

```bash
# Real-time HPA monitoring
kubectl get hpa -w

# Real-time node monitoring
kubectl get nodes -w

# Resource utilization
kubectl top nodes
kubectl top pods

# Detailed HPA information
kubectl describe hpa nginx-app-hpa
```

## 🎨 Presentation Usage

The presentation is designed to be:
- **Self-contained** - All configurations and explanations included
- **Visually rich** - Includes architecture diagrams and flow charts
- **Educational** - Explains concepts with practical examples
- **Demonstrable** - Includes actual test results and outputs

## 📝 Customization

To adapt this for your own presentation:

1. **Update configurations** in the YAML files for your specific needs
2. **Modify resource thresholds** in `hpa.yaml` based on your requirements
3. **Adjust load testing** in `generate-scaling-demo.sh` for your traffic patterns
4. **Add your own metrics** or custom scaling rules as needed

## 🤝 Contributing

Feel free to enhance this presentation by:
- Adding more detailed monitoring examples
- Including cost analysis sections
- Adding performance benchmarking results
- Including additional scaling scenarios

---

**Happy Auto-Scaling! 🚀**

This presentation demonstrates how Kubernetes with HPA and EKS Auto Mode can provide a truly self-managing infrastructure that scales automatically based on real workload demands.
