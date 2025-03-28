# Data Pipeline en Kubernetes

En este módulo, implementaremos un pipeline de datos completo usando Kubernetes, con componentes esenciales para Data Engineering:

1. **PostgreSQL**: Base de datos operacional
2. **Apache Kafka**: Plataforma de streaming
3. **Apache Airflow**: Orquestador de flujos de trabajo

## Arquitectura del Pipeline

Nuestro pipeline tendrá la siguiente arquitectura:

1. Datos generados son insertados en PostgreSQL
2. Un proceso ETL con Airflow extrae los datos de PostgreSQL
3. Los datos procesados se envían a Kafka
4. Un consumidor procesa los mensajes de Kafka

![Arquitectura](https://raw.githubusercontent.com/username/repo/master/images/pipeline-architecture.png)

## Prerequisitos

- Cluster Kubernetes funcionando (configurado en módulo 2)
- Helm instalado (configurado en módulo 2)
- Namespace creado para nuestro pipeline

```bash
# Crear namespace para el pipeline
kubectl create namespace data-pipeline
```

## 1. Despliegue de PostgreSQL

### Usando Helm para instalar PostgreSQL

```bash
# Añadir repositorio de Bitnami si no lo has hecho
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Instalar PostgreSQL
helm install postgres bitnami/postgresql \
  --namespace data-pipeline \
  --set postgresqlUsername=datauser \
  --set postgresqlPassword=datapassword \
  --set postgresqlDatabase=datadb \
  --set persistence.size=1Gi
```

### Verificar instalación

```bash
kubectl get pods -n data-pipeline
kubectl get pvc -n data-pipeline
kubectl get services -n data-pipeline
```

### Acceder a PostgreSQL

```bash
# Obtener contraseña
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data-pipeline postgres-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

# Conectar a PostgreSQL
kubectl run postgres-client --rm --tty -i --restart='Never' --namespace data-pipeline --image docker.io/bitnami/postgresql:latest --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host postgres-postgresql -U datauser -d datadb -p 5432
```

### Crear esquema de prueba

Dentro del cliente PostgreSQL, ejecuta:

```sql
CREATE TABLE sales (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(100),
  amount DECIMAL(10,2),
  sale_date TIMESTAMP
);

INSERT INTO sales (product_name, amount, sale_date) VALUES 
  ('Laptop', 1200.50, NOW()),
  ('Smartphone', 800.99, NOW()),
  ('Tablet', 350.50, NOW()),
  ('Headphones', 150.75, NOW());

SELECT * FROM sales;
```

## 2. Despliegue de Apache Kafka

### Usando Helm para instalar Kafka

```bash
# Instalar Kafka con Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo update

helm install kafka-operator strimzi/strimzi-kafka-operator \
  --namespace data-pipeline \
  --set watchNamespaces="{data-pipeline}"
```

### Crear un cluster Kafka

Crea un archivo `kafka-cluster.yaml`:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: data-cluster
  namespace: data-pipeline
spec:
  kafka:
    version: 3.3.1
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      log.message.format.version: '3.3'
      inter.broker.protocol.version: '3.3'
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 1Gi
        deleteClaim: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 1Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

Aplica la configuración:

```bash
kubectl apply -f kafka-cluster.yaml
```

### Crear un topic Kafka

Crea un archivo `sales-topic.yaml`:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: sales-data
  namespace: data-pipeline
  labels:
    strimzi.io/cluster: data-cluster
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
```

Aplica la configuración:

```bash
kubectl apply -f sales-topic.yaml
```

### Verificar instalación

```bash
kubectl get pods -n data-pipeline | grep kafka
kubectl get kafkatopics -n data-pipeline
```

## 3. Despliegue de Apache Airflow

### Crear configuración de Airflow

Crea un archivo `airflow-values.yaml`:

```yaml
createUserJob:
  useHelmHooks: false

airflow:
  image:
    repository: apache/airflow
    tag: 2.5.1
  executor: CeleryExecutor
  fernetKey: "your-fernet-key"  # Genera con: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
  config:
    AIRFLOW__CORE__LOAD_EXAMPLES: "False"
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: "True"
  users:
    - username: admin
      password: admin
      role: Admin
      email: admin@example.com
      firstname: Admin
      lastname: User

postgresql:
  enabled: true
  postgresqlUsername: airflow
  postgresqlPassword: airflow
  postgresqlDatabase: airflow

redis:
  enabled: true

web:
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

dags:
  persistence:
    enabled: true
    size: 1Gi
  gitSync:
    enabled: false

workers:
  replicas: 2
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
```

### Instalar Airflow con Helm

```bash
# Añadir repositorio de Apache Airflow
helm repo add apache-airflow https://airflow.apache.org
helm repo update

# Instalar Apache Airflow
helm install airflow apache-airflow/airflow \
  --namespace data-pipeline \
  -f airflow-values.yaml
```

### Verificar instalación

```bash
kubectl get pods -n data-pipeline | grep airflow
kubectl get services -n data-pipeline | grep airflow
```

### Acceder a la UI de Airflow

```bash
kubectl port-forward svc/airflow-webserver 8080:8080 -n data-pipeline
```

Visita http://localhost:8080 en tu navegador y usa las credenciales:
- Username: admin
- Password: admin

## 4. Crear DAGs de Airflow para el Pipeline

### Crear PersistentVolumeClaim para los DAGs

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: airflow-dags
  namespace: data-pipeline
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

Aplica la configuración:

```bash
kubectl apply -f airflow-dags-pvc.yaml
```

### Crear ConfigMap para los DAGs

Crea un archivo `dags-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-dags
  namespace: data-pipeline
data:
  extract_load_sales.py: |
    from datetime import datetime, timedelta
    from airflow import DAG
    from airflow.operators.python_operator import PythonOperator
    from airflow.hooks.postgres_hook import PostgresHook
    from airflow.providers.apache.kafka.hooks.producer import KafkaProducerHook
    import json
    
    default_args = {
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2023, 1, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=5),
    }
    
    # Definir DAG
    dag = DAG(
        'extract_load_sales',
        default_args=default_args,
        description='Extract sales data from PostgreSQL and load to Kafka',
        schedule_interval=timedelta(hours=1),
        catchup=False,
    )
    
    def extract_sales():
        # Conectar a PostgreSQL usando la conexión configurada
        pg_hook = PostgresHook(postgres_conn_id='postgres_conn')
        conn = pg_hook.get_conn()
        cursor = conn.cursor()
        
        # Ejecutar consulta
        cursor.execute("SELECT id, product_name, amount, sale_date FROM sales WHERE sale_date > NOW() - INTERVAL '1 hour'")
        records = cursor.fetchall()
        
        # Convertir a formato deseado
        result = []
        for row in records:
            result.append({
                'id': row[0],
                'product_name': row[1],
                'amount': float(row[2]),
                'sale_date': row[3].strftime('%Y-%m-%d %H:%M:%S')
            })
            
        return result
    
    def load_to_kafka(**context):
        # Obtener datos del paso anterior
        ti = context['ti']
        sales_data = ti.xcom_pull(task_ids='extract_sales_task')
        
        if not sales_data:
            print("No hay datos para procesar")
            return
            
        # Conectar a Kafka
        kafka_hook = KafkaProducerHook(kafka_conn_id='kafka_conn')
        producer = kafka_hook.get_producer()
        
        # Enviar cada registro como mensaje
        for sale in sales_data:
            producer.send(
                'sales-data',
                key=str(sale['id']).encode('utf-8'),
                value=json.dumps(sale).encode('utf-8')
            )
            
        producer.flush()
        print(f"Enviados {len(sales_data)} registros a Kafka")
    
    # Definir tareas
    extract_task = PythonOperator(
        task_id='extract_sales_task',
        python_callable=extract_sales,
        dag=dag,
    )
    
    load_task = PythonOperator(
        task_id='load_to_kafka_task',
        python_callable=load_to_kafka,
        provide_context=True,
        dag=dag,
    )
    
    # Definir dependencias
    extract_task >> load_task
```

Aplica la configuración:

```bash
kubectl apply -f dags-configmap.yaml
```

### Montar ConfigMap como volumen en Airflow

Actualiza la configuración de Airflow para montar el ConfigMap:

```yaml
# Actualiza airflow-values.yaml con:
dags:
  gitSync:
    enabled: false
  persistence:
    enabled: true
    existingClaim: airflow-dags

# Añade estas secciones
extraVolumes:
  - name: airflow-dags-config
    configMap:
      name: airflow-dags

extraVolumeMounts:
  - name: airflow-dags-config
    mountPath: /opt/airflow/dags
    readOnly: true
```

Actualiza Airflow:

```bash
helm upgrade airflow apache-airflow/airflow \
  --namespace data-pipeline \
  -f airflow-values.yaml
```

## 5. Crear conexiones en Airflow

Para que el DAG funcione, necesitamos configurar conexiones a PostgreSQL y Kafka en Airflow:

1. Accede a la UI de Airflow: http://localhost:8080
2. Ve a Admin -> Connections

### Añadir conexión a PostgreSQL

- Conn Id: postgres_conn
- Conn Type: Postgres
- Host: postgres-postgresql.data-pipeline.svc.cluster.local
- Schema: datadb
- Login: datauser
- Password: datapassword
- Port: 5432

### Añadir conexión a Kafka

- Conn Id: kafka_conn
- Conn Type: Kafka
- Host: data-cluster-kafka-bootstrap.data-pipeline.svc.cluster.local
- Port: 9092
- Extra: {"security_protocol": "PLAINTEXT"}

## 6. Crear consumidor de Kafka

Vamos a crear un consumidor simple que lea los mensajes de Kafka y los procese.

Crea un archivo `kafka-consumer.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-consumer
  namespace: data-pipeline
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-consumer
  template:
    metadata:
      labels:
        app: kafka-consumer
    spec:
      containers:
      - name: consumer
        image: python:3.9
        command: ["/bin/bash", "-c"]
        args:
          - >
            pip install kafka-python &&
            python -c '
            from kafka import KafkaConsumer
            import json
            import time
            
            # Esperar a que Kafka esté disponible
            time.sleep(30)
            
            # Configurar consumidor
            consumer = KafkaConsumer(
                "sales-data",
                bootstrap_servers=["data-cluster-kafka-bootstrap.data-pipeline.svc.cluster.local:9092"],
                auto_offset_reset="earliest",
                group_id="sales-processor",
                value_deserializer=lambda x: json.loads(x.decode("utf-8"))
            )
            
            # Procesar mensajes
            print("Iniciando consumidor...")
            for message in consumer:
                print(f"Procesando venta: {message.value}")
                # Aquí implementaríamos la lógica de procesamiento real
            '
```

Aplica la configuración:

```bash
kubectl apply -f kafka-consumer.yaml
```

### Verificar funcionamiento

```bash
# Ver logs del consumidor
kubectl logs -f deployment/kafka-consumer -n data-pipeline
```

## 7. Probar el pipeline completo

### Insertar datos de prueba en PostgreSQL

```bash
# Acceder a PostgreSQL
kubectl run postgres-client --rm --tty -i --restart='Never' --namespace data-pipeline --image docker.io/bitnami/postgresql:latest --env="PGPASSWORD=$POSTGRES_PASSWORD" --command -- psql --host postgres-postgresql -U datauser -d datadb -p 5432
```

Dentro del cliente PostgreSQL, ejecuta:

```sql
-- Insertar nuevas ventas
INSERT INTO sales (product_name, amount, sale_date) VALUES 
  ('Monitor 4K', 350.99, NOW()),
  ('Teclado mecánico', 120.50, NOW()),
  ('Mouse gaming', 80.25, NOW());
```

### Activar el DAG en Airflow

1. Accede a la UI de Airflow: http://localhost:8080
2. Busca el DAG 'extract_load_sales'
3. Actívalo y luego activa una ejecución manual

### Verificar resultados

```bash
# Ver logs del consumidor de Kafka
kubectl logs -f deployment/kafka-consumer -n data-pipeline
```

Deberías ver los mensajes procesados con los datos de las ventas.

## 8. Escalado del pipeline

Podemos escalar diferentes componentes según las necesidades:

### Escalar Kafka

Edita `kafka-cluster.yaml` para aumentar réplicas:

```yaml
spec:
  kafka:
    replicas: 5  # Aumenta de 3 a 5
```

Aplica los cambios:

```bash
kubectl apply -f kafka-cluster.yaml
```

### Escalar workers de Airflow

```bash
helm upgrade airflow apache-airflow/airflow \
  --namespace data-pipeline \
  --set workers.replicas=4 \
  -f airflow-values.yaml
```

## Próximos pasos

En el siguiente módulo, implementaremos una plataforma de Data Lakehouse con Apache Iceberg y Trino para analíticos avanzados y consultas SQL sobre grandes volúmenes de datos. 