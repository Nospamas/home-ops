---
# Relay on TrueNAS, see docs/adr/0006
machine:
  logging:
    destinations:
      - endpoint: tcp://192.168.0.51:6051/
        format: json_lines
        extraTags:
          node: {{ .Node.Host }}
