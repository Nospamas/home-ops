---
apiVersion: v1alpha1
kind: BridgeConfig
name: br0
links:
  - eno1
  - enp1s0
stp:
  enabled: false
addresses:
  - address: {{ .Node.IP }}/16
  - address: fd00:192:168::{{ printf "%s" .Node.IP | splitList "." | last }}/64
routes:
  - gateway: 192.168.11.1
    metric: 1024
