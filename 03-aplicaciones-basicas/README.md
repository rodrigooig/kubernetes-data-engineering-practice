# Despliegue de Aplicaciones Básicas en Kubernetes

En este módulo, aprenderemos a desplegar aplicaciones básicas en Kubernetes, enfocándonos en los recursos fundamentales que necesitarás comprender antes de implementar soluciones de Data Engineering más complejas.

## Objetivos

- Crear y gestionar Pods
- Implementar Deployments
- Configurar Services
- Utilizar ConfigMaps y Secrets
- Comprender los Namespaces

## 1. Pods: La Unidad Básica

Los Pods son la unidad más pequeña que podemos crear y gestionar en Kubernetes.

### Ejemplo: Pod con Nginx

Creemos un pod simple con un servidor web Nginx:

```bash
# Crear un directorio para nuestros ejemplos
mkdir -p ejemplos/pod
```

Crea un archivo `nginx-pod.yaml` en el directorio `ejemplos/pod`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

Despliega el pod:

```bash
kubectl apply -f ejemplos/pod/nginx-pod.yaml
```

Verifica que está funcionando:

```bash
kubectl get pods
kubectl describe pod nginx-pod
```

Accede al pod:

```bash
# Redirige puerto local 8080 al puerto 80 del pod
kubectl port-forward nginx-pod 8080:80
```

Ahora puedes abrir http://localhost:8080 en tu navegador para ver Nginx funcionando.

## 2. Deployments: Gestión de Réplicas

Los Deployments son una abstracción de nivel superior que permiten gestionar múltiples réplicas de Pods y proporcionar actualizaciones declarativas.

### Ejemplo: Deployment de Nginx

Crea un archivo `nginx-deployment.yaml` en el directorio `ejemplos/deployment`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
```

Despliega el deployment:

```bash
kubectl apply -f ejemplos/deployment/nginx-deployment.yaml
```

Verifica que está funcionando:

```bash
kubectl get deployments
kubectl get pods
```

Observa que se han creado 3 pods, tal como especificamos.

### Escalado de Deployments

Podemos escalar fácilmente nuestro deployment:

```bash
kubectl scale deployment nginx-deployment --replicas=5
```

Verifica el escalado:

```bash
kubectl get pods
```

## 3. Services: Exposición de Aplicaciones

Los Services proporcionan una manera estable de acceder a un conjunto de Pods.

### Ejemplo: Service para Nginx

Crea un archivo `nginx-service.yaml` en el directorio `ejemplos/service`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

Despliega el service:

```bash
kubectl apply -f ejemplos/service/nginx-service.yaml
```

Verifica que está funcionando:

```bash
kubectl get services
```

Accede al service:

```bash
kubectl port-forward service/nginx-service 8080:80
```

### Tipos de Services

Kubernetes ofrece varios tipos de Services:

- **ClusterIP**: Expone el Service en una IP interna del cluster (predeterminado)
- **NodePort**: Expone el Service en el mismo puerto de cada nodo seleccionado
- **LoadBalancer**: Crea un balanceador de carga externo (en clouds que lo soporten)
- **ExternalName**: Mapea el Service a un nombre DNS

## 4. ConfigMaps y Secrets: Configuración Externa

### ConfigMaps

Los ConfigMaps permiten desacoplar la configuración de los Pods.

#### Ejemplo: ConfigMap para configuración de Nginx

Crea un archivo `nginx-config.yaml` en el directorio `ejemplos/configmap`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      
      location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
      }
      
      location /api {
        return 200 '{"status": "ok", "message": "ConfigMap works!"}';
        add_header Content-Type application/json;
      }
    }
```

Despliega el ConfigMap:

```bash
kubectl apply -f ejemplos/configmap/nginx-config.yaml
```

Ahora, modifica el deployment para usar este ConfigMap:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-config
  labels:
    app: nginx-config
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-config
  template:
    metadata:
      labels:
        app: nginx-config
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
          items:
          - key: nginx.conf
            path: default.conf
```

Despliega este deployment:

```bash
kubectl apply -f ejemplos/configmap/nginx-deployment-config.yaml
```

### Secrets

Los Secrets son similares a los ConfigMaps pero están diseñados para almacenar información sensible.

#### Ejemplo: Secret para credenciales de base de datos

Crea un archivo `db-secret.yaml` en el directorio `ejemplos/secret`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: cG9zdGdyZXM=  # 'postgres' en base64
  password: c2VjcmV0cGFzcw==  # 'secretpass' en base64
```

Despliega el Secret:

```bash
kubectl apply -f ejemplos/secret/db-secret.yaml
```

Ahora, podemos utilizar este Secret en un Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-example-pod
spec:
  containers:
  - name: example
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

Despliega este pod:

```bash
kubectl apply -f ejemplos/secret/secret-example-pod.yaml
```

Verifica que las variables de entorno se han configurado correctamente:

```bash
kubectl exec -it secret-example-pod -- env | grep DB_
```

## 5. Namespaces: Organización y Aislamiento

Los Namespaces proporcionan una forma de organizar y aislar recursos en un cluster.

### Creación de un Namespace

```bash
kubectl create namespace data-engineering
```

### Despliegue en un Namespace específico

Para desplegar recursos en un namespace específico, puedes:

1. Añadir el namespace en el YAML:
```yaml
metadata:
  name: example-resource
  namespace: data-engineering
```

2. Especificar el namespace al aplicar:
```bash
kubectl apply -f example.yaml -n data-engineering
```

### Listar recursos por Namespace

```bash
kubectl get pods -n data-engineering
kubectl get all -n data-engineering
```

## Ejercicio práctico

Vamos a implementar una pequeña aplicación que simula un productor y consumidor de datos, utilizando todos los conceptos aprendidos.

### Paso 1: Crear un ConfigMap para la configuración

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-config
  namespace: data-engineering
data:
  PRODUCER_INTERVAL: "5"
  DATA_FILE: "/data/sample.txt"
  MESSAGE: "Este es un dato de ejemplo generado cada 5 segundos"
```

### Paso 2: Crear un Deployment para el productor

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-producer
  namespace: data-engineering
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-producer
  template:
    metadata:
      labels:
        app: data-producer
    spec:
      containers:
      - name: producer
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - >
            while true; do
              echo "$MESSAGE - $(date)" >> $DATA_FILE;
              echo "Data written to $DATA_FILE";
              sleep $PRODUCER_INTERVAL;
            done
        env:
        - name: PRODUCER_INTERVAL
          valueFrom:
            configMapKeyRef:
              name: data-config
              key: PRODUCER_INTERVAL
        - name: DATA_FILE
          valueFrom:
            configMapKeyRef:
              name: data-config
              key: DATA_FILE
        - name: MESSAGE
          valueFrom:
            configMapKeyRef:
              name: data-config
              key: MESSAGE
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        emptyDir: {}
```

### Paso 3: Crear un Deployment para el consumidor

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-consumer
  namespace: data-engineering
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-consumer
  template:
    metadata:
      labels:
        app: data-consumer
    spec:
      containers:
      - name: consumer
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - >
            while true; do
              if [ -f $DATA_FILE ]; then
                echo "Reading from $DATA_FILE:";
                tail -n 1 $DATA_FILE;
              else
                echo "Waiting for data...";
              fi;
              sleep 10;
            done
        env:
        - name: DATA_FILE
          valueFrom:
            configMapKeyRef:
              name: data-config
              key: DATA_FILE
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        emptyDir: {}
```

### Aplicar configuraciones

Guarda cada archivo YAML en el directorio correspondiente y aplícalos:

```bash
kubectl apply -f ejemplos/ejercicio/data-config.yaml
kubectl apply -f ejemplos/ejercicio/data-producer.yaml
kubectl apply -f ejemplos/ejercicio/data-consumer.yaml
```

### Ver logs

```bash
kubectl logs -f deployment/data-producer -n data-engineering
kubectl logs -f deployment/data-consumer -n data-engineering
```

## Próximos pasos

En el siguiente módulo, utilizaremos estos conceptos básicos para desplegar un data pipeline completo con Apache Airflow, PostgreSQL y otros componentes. 