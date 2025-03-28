# Ejercicios Prácticos y Desafíos

En este módulo final, pondremos en práctica todos los conocimientos adquiridos a través de una serie de ejercicios y desafíos integradores. Estos ejercicios están diseñados para reforzar los conceptos y desarrollar habilidades prácticas en el uso de Kubernetes para Data Engineering.

## Estructura de los Ejercicios

Los ejercicios están organizados en categorías:

1. **Ejercicios Básicos**: Para consolidar conceptos fundamentales
2. **Ejercicios Intermedios**: Para integraciones más complejas
3. **Desafíos Avanzados**: Para implementaciones realistas y soluciones a problemas comunes

## Ejercicios Básicos

### Ejercicio 1: Despliegue manual de componentes

**Objetivo**: Desplegar manualmente (sin Helm) un componente básico de data engineering.

**Tareas**:
1. Crear un namespace `ex-manual`
2. Desplegar PostgreSQL utilizando manifiestos YAML (Deployment, Service, ConfigMap, Secret, PVC)
3. Configurar almacenamiento persistente
4. Verificar la conectividad y funcionamiento

**Archivos necesarios**:

`postgres-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: ex-manual
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

`postgres-secret.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ex-manual
type: Opaque
stringData:
  POSTGRES_USER: ejercicio
  POSTGRES_PASSWORD: password123
  POSTGRES_DB: ejerciciodb
```

`postgres-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ex-manual
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

`postgres-service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ex-manual
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

**Instrucciones**:
```bash
# Crear namespace
kubectl create namespace ex-manual

# Aplicar configuraciones
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

# Verificar despliegue
kubectl get pods -n ex-manual
kubectl get services -n ex-manual
kubectl get pvc -n ex-manual

# Probar conexión
kubectl run pg-client --rm --tty -i --restart='Never' --namespace ex-manual --image=postgres:14 --env="PGPASSWORD=password123" -- psql -h postgres -U ejercicio -d ejerciciodb
```

### Ejercicio 2: Configuración y uso de recursos

**Objetivo**: Entender cómo gestionar recursos (CPU, memoria) y configurar límites para aplicaciones de datos.

**Tareas**:
1. Crear un namespace `ex-recursos`
2. Desplegar un pod con Python que simule procesamiento intensivo
3. Configurar diferentes límites de recursos
4. Observar comportamiento bajo distintas condiciones

**Archivo necesario**:

`python-worker.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: python-worker
  namespace: ex-recursos
spec:
  containers:
  - name: python
    image: python:3.9
    command: ["python", "-c", "import numpy as np; import time; \
              print('Iniciando procesamiento...'); \
              while True: \
                # Crear matriz grande \
                a = np.random.rand(2000, 2000); \
                # Operaciones matriciales intensivas \
                b = np.linalg.inv(np.dot(a.T, a)); \
                print('Iteración completada'); \
                time.sleep(1)"]
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "200Mi"
        cpu: "200m"
```

**Instrucciones**:
```bash
# Crear namespace
kubectl create namespace ex-recursos

# Crear pod con Python
kubectl apply -f python-worker.yaml

# Observar el uso de recursos
kubectl top pod python-worker -n ex-recursos

# Modificar los límites y observar cambios
# Edita python-worker.yaml con nuevos límites
# kubectl delete pod python-worker -n ex-recursos
# kubectl apply -f python-worker-modificado.yaml
```

### Ejercicio 3: Escalado de servicios

**Objetivo**: Aprender a escalar servicios horizontalmente.

**Tareas**:
1. Crear un namespace `ex-escalado`
2. Desplegar una aplicación web simple con un Deployment
3. Escalar la aplicación manualmente
4. Configurar un HorizontalPodAutoscaler

**Archivo necesario**:

`web-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: ex-escalado
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: ex-escalado
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

`web-hpa.yaml`:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: ex-escalado
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

**Instrucciones**:
```bash
# Crear namespace
kubectl create namespace ex-escalado

# Desplegar aplicación
kubectl apply -f web-deployment.yaml

# Escalar manualmente
kubectl scale deployment web-app -n ex-escalado --replicas=3

# Verificar escalado
kubectl get pods -n ex-escalado

# Configurar HPA
kubectl apply -f web-hpa.yaml

# Generar carga para probar HPA
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --namespace=ex-escalado -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://web-app; done"
```

## Ejercicios Intermedios

### Ejercicio 4: Pipeline de datos con operadores personalizados

**Objetivo**: Crear un pipeline de datos simple con Kubernetes utilizando CronJobs.

**Tareas**:
1. Crear un namespace `ex-pipeline`
2. Implementar un CronJob para extracción de datos
3. Implementar un segundo CronJob para transformación
4. Implementar un tercer CronJob para carga
5. Compartir datos entre jobs usando un PVC

**Archivos necesarios**:

`pipeline-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipeline-data
  namespace: ex-pipeline
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

`extract-job.yaml`:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: extract-job
  namespace: ex-pipeline
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: extract
            image: python:3.9
            command: ["/bin/bash", "-c"]
            args:
            - |
              pip install requests pandas
              python -c "
              import pandas as pd
              import requests
              import datetime
              
              # Obtener datos de una API pública
              response = requests.get('https://jsonplaceholder.typicode.com/posts')
              data = response.json()
              
              # Convertir a DataFrame
              df = pd.DataFrame(data)
              
              # Guardar en CSV
              timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
              filename = f'/data/raw_data_{timestamp}.csv'
              df.to_csv(filename, index=False)
              print(f'Datos extraídos a {filename}')
              "
            volumeMounts:
            - name: data-volume
              mountPath: /data
          volumes:
          - name: data-volume
            persistentVolumeClaim:
              claimName: pipeline-data
          restartPolicy: OnFailure
```

`transform-job.yaml`:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: transform-job
  namespace: ex-pipeline
spec:
  schedule: "*/6 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: transform
            image: python:3.9
            command: ["/bin/bash", "-c"]
            args:
            - |
              pip install pandas
              python -c "
              import pandas as pd
              import glob
              import os
              
              # Encontrar el archivo CSV más reciente
              raw_files = glob.glob('/data/raw_data_*.csv')
              if not raw_files:
                  print('No hay archivos para procesar')
                  exit(0)
                  
              latest_file = max(raw_files, key=os.path.getctime)
              print(f'Procesando {latest_file}')
              
              # Cargar y transformar datos
              df = pd.read_csv(latest_file)
              
              # Ejecutar algunas transformaciones
              df['title_length'] = df['title'].apply(len)
              df['body_length'] = df['body'].apply(len)
              
              # Guardar los datos transformados
              timestamp = latest_file.split('_')[-1]
              output_file = f'/data/transformed_data_{timestamp}'
              df.to_csv(output_file, index=False)
              print(f'Datos transformados guardados en {output_file}')
              "
            volumeMounts:
            - name: data-volume
              mountPath: /data
          volumes:
          - name: data-volume
            persistentVolumeClaim:
              claimName: pipeline-data
          restartPolicy: OnFailure
```

`load-job.yaml`:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: load-job
  namespace: ex-pipeline
spec:
  schedule: "*/7 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: load
            image: python:3.9
            command: ["/bin/bash", "-c"]
            args:
            - |
              pip install pandas psycopg2-binary
              python -c "
              import pandas as pd
              import glob
              import os
              import psycopg2
              
              # Encontrar el archivo transformado más reciente
              transformed_files = glob.glob('/data/transformed_data_*.csv')
              if not transformed_files:
                  print('No hay archivos transformados para cargar')
                  exit(0)
                  
              latest_file = max(transformed_files, key=os.path.getctime)
              print(f'Cargando datos de {latest_file}')
              
              # Cargar datos transformados
              df = pd.read_csv(latest_file)
              
              # Conexión a PostgreSQL (asumiendo que postgres ya está configurado)
              try:
                  conn = psycopg2.connect(
                      host='postgres.ex-manual.svc.cluster.local',
                      database='ejerciciodb',
                      user='ejercicio',
                      password='password123'
                  )
                  
                  # Crear tabla si no existe
                  with conn.cursor() as cur:
                      cur.execute('''
                          CREATE TABLE IF NOT EXISTS posts (
                              id INT PRIMARY KEY,
                              userId INT,
                              title TEXT,
                              body TEXT,
                              title_length INT,
                              body_length INT
                          )
                      ''')
                      conn.commit()
                  
                  # Cargar datos
                  print(f'Cargando {len(df)} registros a la base de datos')
                  for _, row in df.iterrows():
                      with conn.cursor() as cur:
                          cur.execute('''
                              INSERT INTO posts (id, userId, title, body, title_length, body_length)
                              VALUES (%s, %s, %s, %s, %s, %s)
                              ON CONFLICT (id) DO UPDATE SET
                                  userId = EXCLUDED.userId,
                                  title = EXCLUDED.title,
                                  body = EXCLUDED.body,
                                  title_length = EXCLUDED.title_length,
                                  body_length = EXCLUDED.body_length
                          ''', (row['id'], row['userId'], row['title'], row['body'], 
                               row['title_length'], row['body_length']))
                      conn.commit()
                  
                  print('Datos cargados exitosamente')
                  
              except Exception as e:
                  print(f'Error en la carga: {e}')
              finally:
                  if conn:
                      conn.close()
              "
            volumeMounts:
            - name: data-volume
              mountPath: /data
          volumes:
          - name: data-volume
            persistentVolumeClaim:
              claimName: pipeline-data
          restartPolicy: OnFailure
```

**Instrucciones**:
```bash
# Crear namespace
kubectl create namespace ex-pipeline

# Aplicar configuraciones
kubectl apply -f pipeline-pvc.yaml
kubectl apply -f extract-job.yaml
kubectl apply -f transform-job.yaml
kubectl apply -f load-job.yaml

# Verificar ejecución
kubectl get cronjobs -n ex-pipeline
kubectl get pods -n ex-pipeline

# Revisar los logs
kubectl logs -l job-name=extract-job -n ex-pipeline
kubectl logs -l job-name=transform-job -n ex-pipeline
kubectl logs -l job-name=load-job -n ex-pipeline

# Verificar los datos en PostgreSQL
kubectl run pg-client --rm --tty -i --restart='Never' --namespace ex-manual --image=postgres:14 --env="PGPASSWORD=password123" -- psql -h postgres -U ejercicio -d ejerciciodb -c "SELECT * FROM posts LIMIT 5;"
```

### Ejercicio 5: Despliegue de un servicio con StatefulSet

**Objetivo**: Comprender el uso de StatefulSets para aplicaciones con estado.

**Tareas**:
1. Crear un namespace `ex-stateful`
2. Desplegar un cluster de Redis usando StatefulSet
3. Configurar almacenamiento persistente
4. Probar la persistencia y alta disponibilidad

**Archivo necesario**:

`redis-statefulset.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: ex-stateful
data:
  redis.conf: |
    dir /data
    appendonly yes
    protected-mode no
    port 6379
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: ex-stateful
spec:
  selector:
    matchLabels:
      app: redis
  serviceName: "redis"
  replicas: 3
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6.2
        command:
          - redis-server
          - "/etc/redis/redis.conf"
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis/
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ex-stateful
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
---
apiVersion: v1
kind: Service
metadata:
  name: redis-access
  namespace: ex-stateful
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

**Instrucciones**:
```bash
# Crear namespace
kubectl create namespace ex-stateful

# Aplicar configuración de Redis
kubectl apply -f redis-statefulset.yaml

# Verificar StatefulSet
kubectl get statefulset -n ex-stateful
kubectl get pods -n ex-stateful
kubectl get pvc -n ex-stateful

# Probar la escritura y lectura en Redis
# Escribir en el primer nodo
kubectl exec -it redis-0 -n ex-stateful -- redis-cli set mykey "Hello StatefulSet"

# Leer desde otros nodos
kubectl exec -it redis-1 -n ex-stateful -- redis-cli get mykey
kubectl exec -it redis-2 -n ex-stateful -- redis-cli get mykey

# Simular falla y recuperación
kubectl delete pod redis-0 -n ex-stateful
kubectl get pods -n ex-stateful -w
# Una vez recuperado el pod
kubectl exec -it redis-0 -n ex-stateful -- redis-cli get mykey
```

## Desafíos Avanzados

### Desafío 1: Orquestación de un pipeline de ML con Kubeflow

**Objetivo**: Implementar un pipeline de Machine Learning usando Kubeflow.

**Tareas**:
1. Instalar Kubeflow en el cluster
2. Crear un pipeline básico de ML con los siguientes pasos:
   - Descarga de datos
   - Preprocesamiento
   - Entrenamiento
   - Evaluación
   - Despliegue del modelo

[Consulta la documentación de Kubeflow](https://www.kubeflow.org/docs/components/pipelines/v1/sdk/build-pipeline/) para implementar este desafío.

### Desafío 2: Implementación de un sistema de Feature Store

**Objetivo**: Implementar un Feature Store para ML utilizando Feast en Kubernetes.

**Tareas**:
1. Desplegar Feast en Kubernetes
2. Configurar fuentes de datos para extraer features
3. Implementar registros de features
4. Integrar con un sistema de servicio de features

[Consulta la documentación de Feast](https://docs.feast.dev/) para implementar este desafío.

### Desafío 3: Sistema de datos en tiempo real

**Objetivo**: Implementar un sistema completo de procesamiento de datos en tiempo real.

**Tareas**:
1. Desplegar Kafka para ingesta de datos
2. Implementar procesamiento en tiempo real con Flink
3. Almacenar resultados en una base de datos en tiempo real
4. Visualizar los datos en un dashboard en tiempo real

Este desafío requiere la integración de múltiples componentes. Investiga la documentación de [Apache Kafka](https://kafka.apache.org/documentation/), [Apache Flink](https://flink.apache.org/docs/stable/) y herramientas de visualización en tiempo real.

## Preguntas de Reflexión

Al finalizar cada ejercicio o desafío, reflexiona sobre las siguientes preguntas:

1. ¿Qué ventajas ofrece Kubernetes para este tipo de aplicación de datos?
2. ¿Cuáles fueron los desafíos principales al implementar la solución?
3. ¿Cómo garantizarías la alta disponibilidad de este sistema en un entorno de producción?
4. ¿Qué aspectos de seguridad deberías considerar?
5. ¿Cómo escalarías la solución para manejar volúmenes de datos más grandes?

## Recursos Adicionales

Para profundizar en los temas tratados, consulta estos recursos:

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Data on Kubernetes Community](https://dok.community/)
- [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)
- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Apache Flink Documentation](https://flink.apache.org/docs/stable/)

## Conclusión

Estos ejercicios y desafíos te han permitido aplicar en la práctica los conceptos aprendidos sobre Kubernetes para Data Engineering. Recuerda que la mejor manera de aprender es experimentando, así que te animamos a modificar estos ejercicios y crear tus propias soluciones para desafíos específicos de tu dominio.

¡Felicidades por completar el proyecto educativo de Kubernetes para Data Engineering! 