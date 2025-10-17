#!/bin/bash

# HPA and EKS Auto Mode Scaling Demonstration Script

echo "=== HPA + EKS Auto Mode Scaling Demonstration ==="
echo ""

# Check initial state
echo "1. Initial Cluster State:"
kubectl get nodes
echo ""

echo "2. Initial HPA Status:"
kubectl get hpa
echo ""

echo "3. Initial Pod Distribution:"
kubectl get pods -o wide
echo ""

# Generate load to trigger scaling
echo "4. Starting Load Generation (this will run for 5 minutes)..."
kubectl apply -f load-generator.yaml
kubectl exec -it load-generator -- /bin/sh -c "
  apk add --no-cache curl &&
  echo 'Generating load for 5 minutes...' &&
  timeout 300 sh -c 'while true; do
    for i in {1..20}; do
      curl -s http://nginx-app-service:80/ > /dev/null &
    done
    wait
    sleep 0.5
  done'
" &
LOAD_PID=$!

echo "Load generation started in background (PID: $LOAD_PID)"
echo "Waiting 2 minutes for scaling to occur..."
sleep 120

# Check scaling status
echo ""
echo "5. Scaling Status After 2 Minutes:"
echo "Nodes:"
kubectl get nodes
echo ""
echo "HPA Status:"
kubectl get hpa
echo ""
echo "Pod Distribution:"
kubectl get pods -o wide
echo ""

# Wait a bit more and check final state
echo "Waiting another 3 minutes for full scaling..."
sleep 180

echo ""
echo "6. Final Scaling Status:"
echo "Nodes:"
kubectl get nodes
echo ""
echo "HPA Status:"
kubectl get hpa
echo ""
echo "Pod Distribution:"
kubectl get pods -o wide
echo ""

# Clean up
echo "7. Cleaning up load generator..."
kubectl delete pod load-generator
echo ""

echo "=== Demonstration Complete ==="
echo ""
echo "Key Results:"
echo "- HPA scaled pods based on resource utilization"
echo "- EKS Auto Mode automatically added new nodes when needed"
echo "- Workload distributed across multiple nodes for optimal performance"
