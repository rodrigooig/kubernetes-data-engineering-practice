# Monitoreo y Logging en Kubernetes para Data Engineering

En este módulo, implementaremos una solución completa de monitoreo y logging para nuestro stack de Data Engineering en Kubernetes. Esto es fundamental para garantizar la operación confiable, detectar y resolver problemas, y optimizar el rendimiento del sistema.

## Arquitectura de Monitoreo y Logging

Nuestra arquitectura constará de:

1. **Prometheus**: Sistema de monitoreo y alertas para métricas
2. **Grafana**: Visualización de métricas y dashboards operacionales
3. **Elasticsearch**: Almacenamiento y búsqueda de logs
4. **Fluentd**: Agregación y procesamiento de logs
5. **Kibana**: Visualización y análisis de logs

![Arquitectura de Monitoreo](https://raw.githubusercontent.com/username/repo/master/images/monitoring-architecture.png)

## Prerequisitos

- Cluster Kubernetes funcionando (configurado en módulo 2)
- Aplicaciones desplegadas (módulos anteriores)
- Helm instalado (configurado en módulo 2)
- Namespace creado para el monitoreo

```bash
# Crear namespace para monitoreo y logging
kubectl create namespace monitoring
```

## 1. Despliegue de Prometheus y Grafana

Usaremos el stack de Prometheus de la comunidad, que incluye Prometheus, Alertmanager, Node Exporter, y Grafana.

### Instalar el stack de Prometheus

```bash
# Añadir repositorio de Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Descargar los valores predeterminados para personalizarlos
helm show values prometheus-community/kube-prometheus-stack > prometheus-values.yaml
```

Modifica el archivo `prometheus-values.yaml` para ajustarlo a nuestras necesidades:

```yaml
# Configuración personalizada para Prometheus y Grafana
grafana:
  adminPassword: admin
  persistence:
    enabled: true
    size: 5Gi
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'data-engineering'
        orgId: 1
        folder: 'Data Engineering'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/data-engineering

prometheus:
  prometheusSpec:
    retention: 15d
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'job']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'null'
      routes:
      - match:
          alertname: Watchdog
        receiver: 'null'
    receivers:
    - name: 'null'
```

Instala el stack con la configuración personalizada:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f prometheus-values.yaml
```

### Verificar instalación

```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring
```

### Acceder a las interfaces de usuario

```bash
# Acceder a Prometheus
kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring

# Acceder a Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Acceder a Alertmanager
kubectl port-forward svc/prometheus-alertmanager 9093:9093 -n monitoring
```

## 2. Configurar Exporters para Componentes de Data Engineering

Para monitorear componentes específicos de nuestro stack de Data Engineering, necesitamos exporters que recopilen métricas especializadas.

### Prometheus JMX Exporter para Kafka

Kafka utiliza JMX para exponer métricas. Podemos configurar el JMX Exporter en nuestros pods de Kafka:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-jmx-exporter-config
  namespace: data-pipeline
data:
  config.yaml: |
    startDelaySeconds: 0
    lowercaseOutputName: true
    rules:
    - pattern: ".*"
```

Luego, modifica el despliegue de Kafka para incluir el exporter:

```yaml
# Añade a la configuración de Kafka (añade a kafka-cluster.yaml)
spec:
  kafka:
    # ... configuración existente
    jvmOptions:
      javaSystemProperties:
        - name: "javax.net.debug"
          value: "ssl"
      gcLoggingEnabled: false
    jmxExporterMetricsConfig:
      # Referencia a tu ConfigMap
      valueFrom:
        configMapKeyRef:
          name: kafka-jmx-exporter-config
          key: config.yaml
```

Aplica la configuración actualizada:

```bash
kubectl apply -f kafka-cluster.yaml
```

### PostgreSQL Exporter

Para PostgreSQL, usaremos un exporter dedicado:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install postgres-exporter prometheus-community/prometheus-postgres-exporter \
  --namespace data-pipeline \
  --set config.datasource.host=postgres-postgresql \
  --set config.datasource.user=datauser \
  --set config.datasource.password=datapassword \
  --set config.datasource.database=datadb \
  --set config.datasource.sslmode=disable
```

### Trino Exporter

Para Trino, crearemos un servicio personalizado que exponga métricas para Prometheus:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-exporter-config
  namespace: data-lakehouse
data:
  config.yaml: |
    trino_host: "trino.data-lakehouse.svc.cluster.local"
    trino_port: 8080
    metrics_port: 9275
    scrape_interval_seconds: 15
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino-exporter
  namespace: data-lakehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trino-exporter
  template:
    metadata:
      labels:
        app: trino-exporter
    spec:
      containers:
      - name: trino-exporter
        image: trinodb/trino-prometheus-exporter:latest
        ports:
        - containerPort: 9275
        volumeMounts:
        - name: config-volume
          mountPath: /etc/trino-exporter/config.yaml
          subPath: config.yaml
      volumes:
      - name: config-volume
        configMap:
          name: trino-exporter-config
---
apiVersion: v1
kind: Service
metadata:
  name: trino-exporter
  namespace: data-lakehouse
  labels:
    app: trino-exporter
spec:
  ports:
  - port: 9275
    targetPort: 9275
    name: metrics
  selector:
    app: trino-exporter
```

Aplica la configuración:

```bash
kubectl apply -f trino-exporter.yaml
```

### Configura ServiceMonitor para recolectar métricas

Ahora, configura Prometheus para recolectar las métricas de estos exporters:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: data-engineering-monitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: kafka-exporter  # Ajusta según tus etiquetas
  namespaceSelector:
    matchNames:
      - data-pipeline
      - data-lakehouse
  endpoints:
  - port: metrics
    interval: 15s
```

Aplica la configuración:

```bash
kubectl apply -f servicemonitor.yaml
```

## 3. Despliegue del stack EFK (Elasticsearch, Fluentd, Kibana)

Para la centralización de logs, desplegaremos el stack EFK.

### Instalar Elasticsearch

```bash
# Añadir repositorio de Elastic
helm repo add elastic https://helm.elastic.co
helm repo update

# Instalar Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace monitoring \
  --set replicas=2 \
  --set minimumMasterNodes=1 \
  --set resources.requests.memory=1Gi \
  --set resources.limits.memory=2Gi \
  --set persistence.enabled=true \
  --set persistence.size=20Gi
```

### Instalar Kibana

```bash
# Instalar Kibana
helm install kibana elastic/kibana \
  --namespace monitoring \
  --set elasticsearchHosts=http://elasticsearch-master:9200
```

### Instalar Fluentd

Crea un archivo `fluentd-values.yaml`:

```yaml
# Configuración personalizada para Fluentd
image:
  repository: fluent/fluentd-kubernetes-daemonset
  tag: v1.14-debian-elasticsearch7-1

configMaps:
  general.conf: |
    <match fluent.**>
      @type null
    </match>

  containers.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <filter kubernetes.**>
      @type kubernetes_metadata
      @id filter_kube_metadata
    </filter>

  output.conf: |
    <match kubernetes.**>
      @type elasticsearch
      hosts elasticsearch-master:9200
      user elastic
      password changeme
      index_name fluentd.${record['kubernetes']['namespace_name']}.%Y%m%d
      type_name fluentd
      include_timestamp true
      <buffer>
        flush_thread_count 8
        flush_interval 5s
        chunk_limit_size 2M
        queue_limit_length 32
        retry_max_interval 30
        retry_forever true
      </buffer>
    </match>
```

Instala Fluentd:

```bash
helm repo add kokuwa https://kokuwaio.github.io/helm-charts
helm repo update

helm install fluentd kokuwa/fluentd-elasticsearch \
  --namespace monitoring \
  -f fluentd-values.yaml
```

### Verificar instalación

```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring
```

### Acceder a Kibana

```bash
kubectl port-forward svc/kibana-kibana 5601:5601 -n monitoring
```

Visita http://localhost:5601 en tu navegador.

## 4. Dashboards de Monitoreo para Data Engineering

Ahora, vamos a crear dashboards específicos para Data Engineering en Grafana.

### Dashboard para Kafka

Crea un archivo `kafka-dashboard.json` con un dashboard para Kafka (ejemplo simplificado):

```json
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.5.5",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "kafka_server_brokertopicmetrics_messagesinpersec_oneminuterate",
          "interval": "",
          "legendFormat": "Messages In/s - {{topic}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Kafka Message Rate",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "refresh": "5s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["kafka"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Kafka Overview",
  "uid": "kafka-overview",
  "version": 1
}
```

### Dashboard para PostgreSQL

Crea un archivo `postgres-dashboard.json` (ejemplo simplificado):

```json
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 2,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.5.5",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "pg_stat_database_tup_fetched",
          "interval": "",
          "legendFormat": "Rows Fetched - {{datname}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "PostgreSQL Row Throughput",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "refresh": "5s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["postgresql"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "PostgreSQL Overview",
  "uid": "postgres-overview",
  "version": 1
}
```

### Importar dashboards a Grafana

Crea un ConfigMap con los dashboards:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-engineering-dashboards
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  kafka-dashboard.json: |-
    # Contenido del archivo kafka-dashboard.json
  postgres-dashboard.json: |-
    # Contenido del archivo postgres-dashboard.json
```

Aplica la configuración:

```bash
kubectl apply -f data-engineering-dashboards.yaml
```

## 5. Configuración de Alertas

Ahora, configuraremos alertas para notificar sobre problemas en nuestro stack de Data Engineering.

### Definir Reglas de Alertas

Crea un archivo `data-engineering-alerts.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: data-engineering-alerts
  namespace: monitoring
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
  - name: data-engineering.rules
    rules:
    - alert: KafkaLowDiskSpace
      expr: kubelet_volume_stats_available_bytes{namespace="data-pipeline"} / kubelet_volume_stats_capacity_bytes{namespace="data-pipeline"} < 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Kafka disk space low (< 10%)"
        description: "Kafka broker {{ $labels.pod }} is running out of disk space."
        
    - alert: PostgreSQLHighConnections
      expr: pg_stat_database_numbackends{datname="datadb"} > 100
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PostgreSQL high connection count"
        description: "PostgreSQL instance has more than 100 connections."
        
    - alert: TrinoQueryFailureRate
      expr: rate(trino_query_failed_total[5m]) / rate(trino_query_started_total[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Trino query failure rate high"
        description: "More than 5% of Trino queries are failing."
        
    - alert: AirflowTaskFailure
      expr: airflow_dag_task_fails_total > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Airflow task failure"
        description: "Airflow DAG {{ $labels.dag_id }} task {{ $labels.task_id }} is failing."
```

Aplica la configuración:

```bash
kubectl apply -f data-engineering-alerts.yaml
```

### Configurar Notificaciones

En Grafana, configura notificaciones para recibir alertas:

1. Ve a Alerting > Notification channels
2. Añade un nuevo canal (email, Slack, PagerDuty, etc.)
3. Configura los detalles del canal
4. Guarda la configuración

## 6. Configuración de Kibana para análisis de logs

Ahora, configuraremos Kibana para analizar los logs de nuestras aplicaciones.

### Crear Index Patterns

1. Abre Kibana en http://localhost:5601
2. Ve a Stack Management > Index Patterns
3. Crea un nuevo index pattern para `fluentd.*`
4. Usa `@timestamp` como Time field
5. Haz clic en Create index pattern

### Crear Dashboards en Kibana

Crea dashboards para visualizar logs específicos:

1. Ve a Dashboard > Create new dashboard
2. Añade visualizaciones para:
   - Logs de error por componente
   - Distribución temporal de logs
   - Top 10 errores más frecuentes

### Configurar Saved Searches

Configura búsquedas guardadas para análisis frecuentes:

1. Error logs en Kafka:
   ```
   kubernetes.namespace_name: data-pipeline AND kubernetes.container_name: kafka* AND log: *ERROR*
   ```

2. Error logs en Trino:
   ```
   kubernetes.namespace_name: data-lakehouse AND kubernetes.container_name: trino AND log: *FAILED*
   ```

3. Errores en Airflow:
   ```
   kubernetes.namespace_name: data-pipeline AND kubernetes.container_name: airflow* AND log: *ERROR*
   ```

## 7. Gestión de eventos y correlación

Para una visión completa del sistema, es útil correlacionar métricas y logs.

### Ejemplo: Correlacionar un problema de rendimiento

Si detectas un problema de rendimiento en Trino:

1. **En Grafana**:
   - Revisa el dashboard de Trino para identificar el momento del problema
   - Observa métricas de CPU, memoria y consultas activas
   - Identifica consultas lentas o con alta utilización de recursos

2. **En Kibana**:
   - Busca logs en el mismo período de tiempo
   - Filtra por trino y niveles de log WARNING o ERROR
   - Busca patrones o mensajes de error que coincidan con el problema

3. **Correlación**:
   - Compara la línea de tiempo entre métricas y logs
   - Identifica la causa raíz (consulta mal optimizada, fallo de nodo, etc.)
   - Documenta el patrón para futura referencia

## 8. Automatización de la respuesta a incidentes

Podemos automatizar algunas respuestas a incidentes comunes.

### Ejemplo: Script de auto-recuperación para Kafka

Crea un script que responda a alertas de Kafka:

```bash
#!/bin/bash
# kafka-recover.sh
# Script para auto-recuperación de brokers Kafka con problemas

# Obtener el pod con problemas
PROBLEM_POD=$1

# Verificar el estado del pod
kubectl describe pod $PROBLEM_POD -n data-pipeline > /tmp/pod-status.txt

# Si es un problema de recursos, escalar los recursos
if grep -q "OOMKilled" /tmp/pod-status.txt; then
  echo "Pod killed due to OOM. Increasing memory..."
  # Aumentar memoria en la configuración del StatefulSet
  kubectl patch statefulset $PROBLEM_POD -n data-pipeline --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"2Gi"}]'
fi

# Notificar al equipo
echo "Auto-recovery actions taken for $PROBLEM_POD. Please review." | mail -s "Kafka Recovery" team@example.com
```

## Próximos pasos

En el último módulo, pondremos en práctica todos los conocimientos adquiridos a través de ejercicios y desafíos más complejos, integrando todos los componentes de nuestro stack de Data Engineering. 