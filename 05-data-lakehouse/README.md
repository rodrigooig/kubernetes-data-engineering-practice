# Data Lakehouse con Apache Iceberg y Trino en Kubernetes

En este módulo, desplegaremos una arquitectura moderna de Data Lakehouse utilizando Apache Iceberg como formato de tabla y Trino (anteriormente PrestoSQL) como motor de consulta distribuida, todo orquestado con Kubernetes.

## Arquitectura del Data Lakehouse

Nuestra arquitectura consistirá en:

1. **MinIO**: Almacenamiento compatible con S3 que actuará como nuestro Data Lake
2. **Apache Iceberg**: Formato de tablas de código abierto que proporciona versionado, control de concurrencia y evolución de esquema
3. **Trino**: Motor de consulta SQL distribuido para procesar grandes volúmenes de datos
4. **Hive Metastore**: Servicio de metadatos para almacenar información sobre las tablas Iceberg

![Arquitectura Data Lakehouse](https://raw.githubusercontent.com/username/repo/master/images/lakehouse-architecture.png)

## Prerequisitos

- Cluster Kubernetes funcionando (configurado en módulo 2)
- Helm instalado (configurado en módulo 2)
- Namespace creado para nuestro Data Lakehouse

```bash
# Crear namespace para el data lakehouse
kubectl create namespace data-lakehouse
```

## 1. Despliegue de MinIO

MinIO es un servidor de almacenamiento compatible con Amazon S3, perfecto para nuestro Data Lake.

### Instalación de MinIO con Helm

```bash
# Añadir repositorio de MinIO
helm repo add minio https://charts.min.io/
helm repo update

# Instalar MinIO
helm install minio minio/minio \
  --namespace data-lakehouse \
  --set resources.requests.memory=1Gi \
  --set persistence.size=10Gi \
  --set accessKey=minio \
  --set secretKey=minio123 \
  --set service.type=ClusterIP
```

### Verificar instalación

```bash
kubectl get pods -n data-lakehouse
kubectl get services -n data-lakehouse
```

### Acceder al UI de MinIO

```bash
kubectl port-forward svc/minio 9000:9000 -n data-lakehouse
kubectl port-forward svc/minio 9001:9001 -n data-lakehouse
```

Ahora puedes acceder a:
- Interfaz S3 en http://localhost:9000 
- Consola de administración en http://localhost:9001

Utiliza las credenciales:
- Username: minio
- Password: minio123

### Crear buckets para Iceberg

A través de la consola de MinIO, crea dos buckets:
1. `iceberg-data`: para almacenar los datos
2. `iceberg-warehouse`: para almacenar los metadatos de Iceberg

También puedes hacerlo vía CLI:

```bash
# Instalar cliente MinIO mc
brew install minio/stable/mc # MacOS
# O para Linux
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

# Configurar cliente
mc alias set minio-local http://localhost:9000 minio minio123

# Crear buckets
mc mb minio-local/iceberg-data
mc mb minio-local/iceberg-warehouse
```

## 2. Despliegue de Hive Metastore

Hive Metastore será utilizado por Iceberg para almacenar metadatos de tablas.

### Crear ConfigMaps para Hive

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hive-site
  namespace: data-lakehouse
data:
  hive-site.xml: |
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <configuration>
      <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>s3a://iceberg-warehouse/</value>
      </property>
      <property>
        <name>hive.metastore.uris</name>
        <value>thrift://hive-metastore:9083</value>
      </property>
      <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:postgresql://hive-postgres:5432/metastore</value>
      </property>
      <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.postgresql.Driver</value>
      </property>
      <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
      </property>
      <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>hive</value>
      </property>
      <property>
        <name>fs.s3a.endpoint</name>
        <value>http://minio:9000</value>
      </property>
      <property>
        <name>fs.s3a.access.key</name>
        <value>minio</value>
      </property>
      <property>
        <name>fs.s3a.secret.key</name>
        <value>minio123</value>
      </property>
      <property>
        <name>fs.s3a.path.style.access</name>
        <value>true</value>
      </property>
      <property>
        <name>fs.s3a.impl</name>
        <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
      </property>
    </configuration>
```

Guarda este archivo como `hive-site-configmap.yaml` y aplícalo:

```bash
kubectl apply -f hive-site-configmap.yaml
```

### Desplegar PostgreSQL para Hive Metastore

```bash
# Instalar PostgreSQL para Hive Metastore
helm install hive-postgres bitnami/postgresql \
  --namespace data-lakehouse \
  --set postgresqlUsername=hive \
  --set postgresqlPassword=hive \
  --set postgresqlDatabase=metastore \
  --set persistence.size=1Gi
```

### Desplegar Hive Metastore

Crea un archivo `hive-metastore.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hive-metastore
  namespace: data-lakehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hive-metastore
  template:
    metadata:
      labels:
        app: hive-metastore
    spec:
      containers:
      - name: hive-metastore
        image: apache/hive:3.1.3
        command: ["/bin/bash"]
        args:
        - -c
        - |
          /opt/hive/bin/schematool -dbType postgres -initSchema &&
          /opt/hive/bin/hive --service metastore
        ports:
        - containerPort: 9083
        volumeMounts:
        - name: hive-site
          mountPath: /opt/hive/conf/hive-site.xml
          subPath: hive-site.xml
        env:
        - name: HADOOP_HOME
          value: /opt/hadoop
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: hive-site
        configMap:
          name: hive-site
---
apiVersion: v1
kind: Service
metadata:
  name: hive-metastore
  namespace: data-lakehouse
spec:
  ports:
  - port: 9083
    targetPort: 9083
  selector:
    app: hive-metastore
```

Aplica la configuración:

```bash
kubectl apply -f hive-metastore.yaml
```

## 3. Despliegue de Trino

Trino nos permitirá ejecutar consultas SQL sobre los datos almacenados en Iceberg.

### Crear ConfigMaps para Trino

Crea un archivo `trino-configs.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-configs
  namespace: data-lakehouse
data:
  config.properties: |
    coordinator=true
    node-scheduler.include-coordinator=true
    http-server.http.port=8080
    discovery-server.enabled=true
    discovery.uri=http://trino:8080
    
  jvm.config: |
    -server
    -Xmx4G
    -XX:+UseG1GC
    -XX:G1HeapRegionSize=32M
    -XX:+UseGCOverheadLimit
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+ExitOnOutOfMemoryError
    
  log.properties: |
    io.trino=INFO
    
  catalog/iceberg.properties: |
    connector.name=iceberg
    hive.metastore.uri=thrift://hive-metastore:9083
    iceberg.file-format=PARQUET
    iceberg.compression-codec=GZIP
    hive.s3.endpoint=http://minio:9000
    hive.s3.path-style-access=true
    hive.s3.aws-access-key=minio
    hive.s3.aws-secret-key=minio123
    hive.s3.ssl.enabled=false
```

Aplica la configuración:

```bash
kubectl apply -f trino-configs.yaml
```

### Desplegar Trino

Crea un archivo `trino.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trino
  namespace: data-lakehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trino
  template:
    metadata:
      labels:
        app: trino
    spec:
      containers:
      - name: trino
        image: trinodb/trino:391
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config-volume
          mountPath: /etc/trino/config.properties
          subPath: config.properties
        - name: config-volume
          mountPath: /etc/trino/jvm.config
          subPath: jvm.config
        - name: config-volume
          mountPath: /etc/trino/log.properties
          subPath: log.properties
        - name: config-volume
          mountPath: /etc/trino/catalog/iceberg.properties
          subPath: catalog/iceberg.properties
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
      volumes:
      - name: config-volume
        configMap:
          name: trino-configs
---
apiVersion: v1
kind: Service
metadata:
  name: trino
  namespace: data-lakehouse
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: trino
```

Aplica la configuración:

```bash
kubectl apply -f trino.yaml
```

### Verificar instalación de Trino

```bash
kubectl get pods -n data-lakehouse
kubectl get services -n data-lakehouse
```

### Acceder a la UI de Trino

```bash
kubectl port-forward svc/trino 8080:8080 -n data-lakehouse
```

Visita http://localhost:8080 en tu navegador.

## 4. Cargando datos en Iceberg y consultando con Trino

Ahora que tenemos nuestra infraestructura lista, vamos a cargar algunos datos y ejecutar consultas.

### Crear un pod cliente para interactuar con Trino

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: trino-client
  namespace: data-lakehouse
spec:
  containers:
  - name: trino-cli
    image: trinodb/trino:391
    command: ["sleep", "infinity"]
```

Guarda este archivo como `trino-client.yaml` y aplícalo:

```bash
kubectl apply -f trino-client.yaml
```

### Crear esquema y tablas

Accede al cliente Trino:

```bash
kubectl exec -it trino-client -n data-lakehouse -- bash

# Dentro del pod, ejecuta el cliente Trino
trino --server trino:8080 --catalog iceberg
```

Una vez dentro del cliente Trino, crea un esquema y una tabla:

```sql
-- Crear un esquema
CREATE SCHEMA IF NOT EXISTS iceberg.sales;

-- Crear una tabla Iceberg
CREATE TABLE iceberg.sales.products (
  product_id INTEGER,
  name VARCHAR,
  category VARCHAR,
  price DECIMAL(10, 2),
  created_at TIMESTAMP
);

-- Insertar algunos datos
INSERT INTO iceberg.sales.products VALUES
  (1, 'Laptop Pro', 'Electronics', 1299.99, TIMESTAMP '2023-01-15 10:00:00'),
  (2, 'Smartphone X', 'Electronics', 999.99, TIMESTAMP '2023-01-16 11:30:00'),
  (3, 'Coffee Maker', 'Kitchen', 79.99, TIMESTAMP '2023-01-17 09:15:00'),
  (4, 'Gaming Console', 'Electronics', 499.99, TIMESTAMP '2023-01-18 14:20:00'),
  (5, 'Wireless Headphones', 'Audio', 199.99, TIMESTAMP '2023-01-19 16:45:00');

-- Crear una tabla de ventas
CREATE TABLE iceberg.sales.transactions (
  transaction_id INTEGER,
  product_id INTEGER,
  quantity INTEGER,
  total_amount DECIMAL(10, 2),
  transaction_date TIMESTAMP
);

-- Insertar datos de transacciones
INSERT INTO iceberg.sales.transactions VALUES
  (101, 1, 1, 1299.99, TIMESTAMP '2023-02-10 14:30:00'),
  (102, 2, 2, 1999.98, TIMESTAMP '2023-02-11 10:15:00'),
  (103, 3, 3, 239.97, TIMESTAMP '2023-02-12 11:20:00'),
  (104, 4, 1, 499.99, TIMESTAMP '2023-02-13 16:40:00'),
  (105, 5, 2, 399.98, TIMESTAMP '2023-02-14 09:30:00'),
  (106, 1, 1, 1299.99, TIMESTAMP '2023-02-15 15:10:00');
```

### Ejecutar consultas

```sql
-- Consulta simple
SELECT * FROM iceberg.sales.products;

-- Consulta con JOIN
SELECT 
  t.transaction_id,
  p.name,
  t.quantity,
  t.total_amount,
  t.transaction_date
FROM 
  iceberg.sales.transactions t
JOIN 
  iceberg.sales.products p ON t.product_id = p.product_id;

-- Consulta con agregaciones
SELECT 
  p.category,
  COUNT(*) as num_transactions,
  SUM(t.quantity) as total_items_sold,
  SUM(t.total_amount) as total_revenue
FROM 
  iceberg.sales.transactions t
JOIN 
  iceberg.sales.products p ON t.product_id = p.product_id
GROUP BY 
  p.category
ORDER BY 
  total_revenue DESC;
```

### Explorar características avanzadas de Iceberg

Iceberg proporciona características avanzadas como viajes en el tiempo (time travel), control de versiones y evolución del esquema.

#### Time Travel

```sql
-- Ver historial de versiones de la tabla
SELECT * FROM iceberg.sales.products.history;

-- Consultar una versión específica (reemplaza X con un ID de snapshot)
SELECT * FROM iceberg.sales.products FOR VERSION AS OF X;

-- Consultar datos a una hora específica
SELECT * FROM iceberg.sales.products FOR TIMESTAMP AS OF TIMESTAMP '2023-02-15 12:00:00';
```

#### Evolución del esquema

```sql
-- Añadir una nueva columna
ALTER TABLE iceberg.sales.products ADD COLUMN stock INTEGER;

-- Actualizar los productos con información de stock
UPDATE iceberg.sales.products SET stock = 100 WHERE product_id = 1;
UPDATE iceberg.sales.products SET stock = 50 WHERE product_id = 2;
UPDATE iceberg.sales.products SET stock = 30 WHERE product_id = 3;
UPDATE iceberg.sales.products SET stock = 20 WHERE product_id = 4;
UPDATE iceberg.sales.products SET stock = 75 WHERE product_id = 5;
```

#### Optimización de tablas

```sql
-- Compactar archivos pequeños
CALL iceberg.system.rewrite_data_files('sales.products');

-- Eliminar archivos de snapshots antiguos
CALL iceberg.system.expire_snapshots('sales.products', 30);
```

## 5. Integración con Apache Spark (opcional)

Si deseas procesar datos con Spark y luego cargarlos en Iceberg, puedes desplegar Spark en tu cluster Kubernetes.

### Desplegar Spark Operator

```bash
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
helm repo update

helm install spark-operator spark-operator/spark-operator \
  --namespace data-lakehouse \
  --set webhook.enable=true \
  --set image.tag=v1beta2-1.3.0-3.1.1
```

### Crear un Job Spark que cargue datos en Iceberg

```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: spark-iceberg-job
  namespace: data-lakehouse
spec:
  type: Scala
  mode: cluster
  image: "datamechanics/spark:3.1.2-hadoop-3.2.0-java-8-scala-2.12-python-3.8-latest"
  imagePullPolicy: Always
  mainClass: org.example.IcebergWriter
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-iceberg-example.jar"
  sparkVersion: "3.1.2"
  restartPolicy:
    type: Never
  volumes:
    - name: "spark-conf"
      configMap:
        name: "spark-conf"
  driver:
    cores: 1
    memory: "1G"
    serviceAccount: spark
    volumeMounts:
      - name: "spark-conf"
        mountPath: "/opt/spark/conf"
  executor:
    cores: 1
    instances: 2
    memory: "1G"
    volumeMounts:
      - name: "spark-conf"
        mountPath: "/opt/spark/conf"
  sparkConf:
    "spark.sql.extensions": "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
    "spark.sql.catalog.iceberg": "org.apache.iceberg.spark.SparkCatalog"
    "spark.sql.catalog.iceberg.type": "hive"
    "spark.sql.catalog.iceberg.uri": "thrift://hive-metastore:9083"
    "spark.hadoop.fs.s3a.endpoint": "http://minio:9000"
    "spark.hadoop.fs.s3a.access.key": "minio"
    "spark.hadoop.fs.s3a.secret.key": "minio123"
    "spark.hadoop.fs.s3a.path.style.access": "true"
    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem"
```

## 6. Monitoreo del Data Lakehouse

Para monitorear nuestro Data Lakehouse, podemos utilizar Prometheus y Grafana.

### Instalar Prometheus y Grafana

```bash
# Añadir repositorio de Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar Prometheus Stack (incluye Grafana)
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace data-lakehouse \
  --set grafana.adminPassword=admin
```

### Configurar Dashboard para Trino

Puedes crear dashboards en Grafana para monitorear el rendimiento de Trino, utilizando métricas como:

- Número de consultas en ejecución
- Tiempo de ejecución de consultas
- Uso de memoria
- CPU utilizada

Accede a Grafana:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n data-lakehouse
```

Visita http://localhost:3000 y usa las credenciales:
- Username: admin
- Password: admin

## Próximos pasos

En el siguiente módulo, aprenderemos a integrar herramientas de visualización como Apache Superset para construir dashboards sobre nuestros datos en Iceberg. 