#!/bin/bash
# IPv6 Connectivity Test Script for Cilium

echo "=========================================="
echo "IPv6 Cilium Connectivity Test Results"
echo "=========================================="
echo ""

# Get pod IPs
echo "📍 Pod IPv6 Addresses:"
kubectl get pods -n ipv6-test -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIPs[*].ip}{"\n"}{end}'
echo ""

# Get service IPs
echo "📍 Service IPv6 Addresses:"
kubectl get svc -n ipv6-test -o wide
echo ""

POD1_IP6=$(kubectl get pod -n ipv6-test ipv6-test-pod-1 -o jsonpath='{.status.podIPs[1].ip}')
POD2_IP6=$(kubectl get pod -n ipv6-test ipv6-test-pod-2 -o jsonpath='{.status.podIPs[1].ip}')

echo "=========================================="
echo "Test 1: Pod-to-Pod IPv6 ICMP (ping6)"
echo "=========================================="
echo "🔹 Pod-1 → Pod-2 ($POD2_IP6)"
kubectl exec -n ipv6-test ipv6-test-pod-1 -- ping6 -c 3 -W 2 "$POD2_IP6" 2>&1 | tail -2
echo ""
echo "🔹 Pod-2 → Pod-1 ($POD1_IP6)"
kubectl exec -n ipv6-test ipv6-test-pod-2 -- ping6 -c 3 -W 2 "$POD1_IP6" 2>&1 | tail -2
echo ""

echo "=========================================="
echo "Test 2: Pod-to-Pod IPv6 TCP (HTTP)"
echo "=========================================="
# Start simple HTTP server on pod-2
kubectl exec -n ipv6-test ipv6-test-pod-2 -- sh -c "echo 'Hello from Pod-2 via IPv6' > /tmp/index.html && nohup python3 -m http.server 8080 --bind '::' --directory /tmp > /dev/null 2>&1 &" || true
sleep 2

echo "🔹 Pod-1 → Pod-2 HTTP on IPv6"
kubectl exec -n ipv6-test ipv6-test-pod-1 -- curl -6 -s -m 5 "http://[${POD2_IP6}]:8080/" || echo "❌ Failed"
echo ""

echo "=========================================="
echo "Test 3: Service IPv6 Connectivity"
echo "=========================================="
SVC2_IP6=$(kubectl get svc -n ipv6-test ipv6-test-svc-2 -o jsonpath='{.spec.clusterIPs[0]}')
echo "🔹 Pod-1 → Service-2 HTTP on IPv6 ($SVC2_IP6)"
kubectl exec -n ipv6-test ipv6-test-pod-1 -- curl -6 -s -m 5 "http://[${SVC2_IP6}]:80/" 2>&1 || echo "Note: Service not listening on port 80"
echo ""

echo "=========================================="
echo "Test 4: DNS Resolution (AAAA records)"
echo "=========================================="
echo "🔹 Resolve ipv6-test-svc-2.ipv6-test.svc.cluster.local"
kubectl exec -n ipv6-test ipv6-test-pod-1 -- nslookup ipv6-test-svc-2.ipv6-test.svc.cluster.local 2>&1 | grep -A 2 "Name:"
echo ""

echo "=========================================="
echo "Test 5: IPv6 Routing Information"
echo "=========================================="
echo "🔹 IPv6 Routes in Pod-1:"
kubectl exec -n ipv6-test ipv6-test-pod-1 -- ip -6 route show
echo ""

echo "=========================================="
echo "Test 6: Cilium Endpoint Information"
echo "=========================================="
POD1_ID=$(kubectl get pod -n ipv6-test ipv6-test-pod-1 -o jsonpath='{.metadata.uid}')
echo "🔹 Cilium endpoint for Pod-1:"
kubectl exec -n kube-system ds/cilium -- cilium endpoint list | grep -E "IDENTITY|$POD1_ID" | head -2 || echo "Run on node directly for full endpoint info"
echo ""

echo "=========================================="
echo "✅ IPv6 Tests Complete"
echo "=========================================="
