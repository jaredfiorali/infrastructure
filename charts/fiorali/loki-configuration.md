# Loki Configuration Override

This file overrides the default values from the Grafana Loki Helm chart (`https://grafana-community.github.io/helm-charts`).

See `/Users/jared/Documents/infrastructure/charts/fiorali/values.yaml` for the chart's default values.

## Key Configuration

The actual Loki configuration is managed in **ArgoCD** via the application resource. The helm parameters are "baked in" to the Argo application definition, not stored in this file.

## Helm Parameters (managed in ArgoCD)

```
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: "250m"
      memory: "2Gi"
    limits:
      memory: "4Gi"
  extraVolumes:
    - name: loki-tmpfs
      emptyDir:
        medium: Memory
        sizeLimit: "2Gi"
  extraVolumeMounts:
    - name: loki-tmpfs
      mountPath: /tmp/loki
backend.replicas: 0
bloomBuilder.replicas: 0
bloomGateway.replicas: 0
bloomPlanner.replicas: 0
compactor.replicas: 0
distributor.replicas: 0
indexGateway.replicas: 0
ingester.replicas: 0
querier.replicas: 0
queryFrontend.replicas: 0
queryScheduler.replicas: 0
read.replicas: 0
write.replicas: 0
chunksCache.allocatedMemory: "1024"
schemaConfig.configs[0].from: "2024-04-01"
schemaConfig.configs[0].index.period: "24h"
schemaConfig.configs[0].index.prefix: "loki_index_"
schemaConfig.configs[0].object_store: filesystem
schemaConfig.configs[0].schema: v13
schemaConfig.configs[0].store: tsdb
storage.type: filesystem
storage_config.filesystem.directory: /tmp/loki/chunks
storage_config.tsdb_shipper.active_index_directory: /tmp/loki/index
storage_config.tsdb_shipper.cache_location: /tmp/loki/index_cache
loki.ingester.chunk_encoding: zstd
loki.ingester.chunk_idle_period: 2h
loki.ingester.chunk_target_size: "1572864"
loki.ingester.lifecycler.ring.kvstore.store: inmemory
loki.ingester.wal.enabled: true
loki.ingester.wal.dir: /tmp/loki/wal
loki.querier.max_concurrent: 4
loki.querier.tail_max_duration: 24h
loki.commonConfig.replication_factor: 1
loki.limits_config.max_streams_per_user: 5000
loki.limits_config.retention_period: 48h
loki.limits_config.allow_structured_metadata: true
loki.limits_config.volume_enabled: true
loki.limits_config.max_concurrent_tail_requests: 15
loki.compactor.compaction_interval: 2h
loki.compactor.retention_enabled: true
loki.compactor.delete_request_store: filesystem
loki.compactor.delete_request_store_key_prefix: delete-requests/
loki.compactor.working_directory: /tmp/loki/compactor
loki.pattern_ingester.enabled: true
loki.queryRange.results_cache.cache.embedded_cache.enabled: true
loki.queryRange.results_cache.cache.embedded_cache.max_size_mb: "256"
lokiCanary.enabled: true
ingress.enabled: true
ingress.hosts[0]: loki.fiora.li
ingress.paths.querier[2]: /ready
test.enabled: false
```

## Components

### SingleBinary
- The main Loki pod running in SingleBinary mode
- 4Gi memory limit, 2Gi tempfs for index
- WAL-enabled with zstd compression

### Gateway
- HTTP API gateway for Loki
- ClusterIP service type

### Canary
- DaemonSet with one pod per node (10 total)
- Monitors Loki availability and writes test logs
- Health checks via HTTP metrics

### Chunks Cache
- 1GB allocated memory
- Persistent volume for chunk storage

### Results Cache
- 256MB embedded cache
- Caches query results for faster repeated queries

## Troubleshooting

- **High memory usage**: Check `kubectl top pods -n loki` to see individual component usage
- **Stale canary pods**: The canary may need to be restarted if showing old restarts
- **Index issues**: Check the tmpfs mount at `/tmp/loki/index`
- **Retention**: Currently 48h; adjust `loki.limits_config.retention_period` to change
- **Scale issues**: Add more ingesters by setting `ingester.replicas: 2` and reconfiguring the ring
