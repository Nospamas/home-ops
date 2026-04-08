# IPv6 Cross-Node Routing Test Results

## Test Setup

Two test pods with anti-affinity rules to ensure cross-node placement:

- **Pod 1**: `ipv6-test-pod-1` on `ctrl-02`
  - IPv4: `10.42.4.100`
  - IPv6: `fd00:10:42:2::f6a7`

- **Pod 2**: `ipv6-test-pod-2` on `ctrl-01`
  - IPv4: `10.42.2.89`
  - IPv6: `fd00:10:42:1::594`

## Test Results ✅

### 1. Cross-Node ICMP (ping6)
- **ctrl-02 → ctrl-01**: ✅ 4/4 packets, ~0.2ms latency, TTL=62
- **ctrl-01 → ctrl-02**: ✅ 4/4 packets, ~0.2ms latency, TTL=62

### 2. Cross-Node TCP/HTTP over IPv6
- **ctrl-02 → ctrl-01:8080**: ✅ HTTP request successful
- Verified application-level traffic works over IPv6

### 3. Routing Path
- TTL of 62 (vs 64 initial) indicates 2 hops through Cilium routing
- Traceroute shows routing through intermediate gateways

## Configuration

Cilium is configured with:
- IPv6 enabled: `ipv6.enabled: true`
- IPv6 CIDR: `fd00:10:42::/56`
- Native routing CIDR: `fd00:10:42::/56`
- IPAM mode: `kubernetes`
- Auto direct node routes: `true`

## Commands to Reproduce

```bash
# View pod placement
kubectl get pods -n ipv6-test -o wide

# Get IPv6 addresses
kubectl get pods -n ipv6-test -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIPs[*].ip}{"\n"}{end}'

# Test connectivity
kubectl exec -n ipv6-test ipv6-test-pod-1 -- ping6 -c 4 fd00:10:42:1::594
kubectl exec -n ipv6-test ipv6-test-pod-2 -- ping6 -c 4 fd00:10:42:2::f6a7

# Test HTTP traffic
kubectl exec -n ipv6-test ipv6-test-pod-2 -- python3 -m http.server 8080 --bind '::'
kubectl exec -n ipv6-test ipv6-test-pod-1 -- curl -6 "http://[fd00:10:42:1::594]:8080/"
```

## Cleanup

```bash
kubectl delete namespace ipv6-test
```

## Conclusion

✅ **IPv6 cross-node routing is working correctly on Cilium**
- Bidirectional connectivity confirmed
- Both ICMP and TCP traffic work
- Routing between different subnets (fd00:10:42:1:: and fd00:10:42:2::) successful
