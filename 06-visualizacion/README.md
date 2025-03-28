# Visualización y Análisis con Apache Superset y Grafana

En este módulo, desplegaremos herramientas de visualización y análisis para explorar y presentar los datos procesados en nuestro Data Lakehouse. Utilizaremos Apache Superset para análisis interactivo y creación de dashboards de negocio, y Grafana para monitoreo operacional.

## Arquitectura de Visualización

Nuestra arquitectura de visualización constará de:

1. **Apache Superset**: Plataforma de business intelligence para crear dashboards interactivos y exploración ad-hoc de datos
2. **Grafana**: Herramienta para monitoreo técnico y visualización de métricas operacionales
3. **Conexiones a fuentes de datos**: Configuración para consultar datos de Trino/Iceberg y otras fuentes

![Arquitectura de Visualización](https://raw.githubusercontent.com/username/repo/master/images/visualization-architecture.png)

## Prerequisitos

- Cluster Kubernetes funcionando (configurado en módulo 2)
- Data Lakehouse con Trino y Apache Iceberg (configurado en módulo 5)
- Helm instalado (configurado en módulo 2)
- Namespace creado para nuestras herramientas de visualización

```bash
# Crear namespace para las herramientas de visualización
kubectl create namespace data-viz
```

## 1. Despliegue de Apache Superset

Apache Superset es una plataforma moderna de business intelligence que permite a los usuarios explorar y visualizar sus datos a través de una interfaz intuitiva.

### Crear Secret para Superset

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: superset-secrets
  namespace: data-viz
type: Opaque
stringData:
  admin-user: admin
  admin-password: admin
  secret-key: "thisISaSECRET_1234"
```

Guarda este archivo como `superset-secret.yaml` y aplícalo:

```bash
kubectl apply -f superset-secret.yaml
```

### Instalar Apache Superset con Helm

```bash
# Añadir repositorio de Superset
helm repo add superset https://apache.github.io/superset
helm repo update

# Descargar y personalizar values para Superset
curl -O https://raw.githubusercontent.com/apache/superset/master/helm/superset/values.yaml
```

Modifica el archivo `values.yaml` descargado para incluir nuestra configuración personalizada:

```yaml
# Configuración personalizada para Superset
extraSecretEnv:
  ADMIN_USERNAME:
    name: superset-secrets
    key: admin-user
  ADMIN_PASSWORD:
    name: superset-secrets
    key: admin-password
  SECRET_KEY:
    name: superset-secrets
    key: secret-key

extraConfigs:
  trino_connection.py: |
    import os
    from flask_appbuilder.security.manager import AUTH_DB
    
    # Configuración de Flask-AppBuilder
    AUTH_TYPE = AUTH_DB
    
    # Configuraciones adicionales
    FEATURE_FLAGS = {
        "ENABLE_TEMPLATE_PROCESSING": True,
    }
    
    # Drivers de bases de datos
    # Puedes añadir más drivers si es necesario
    ADDITIONAL_DRIVERS = ["trino", "postgresql"]

extraEnv:
  SUPERSET_LOAD_EXAMPLES: "no"
  SUPERSET_ENV: production
  PYTHONPATH: "/app/pythonpath:/app/docker/pythonpath"

service:
  type: ClusterIP
  port: 8088

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

# Especificación de parámetros para inicialización
init:
  enabled: true
  loadExamples: false
  createAdmin: true
  adminUser:
    username: admin
    firstname: Superset
    lastname: Admin
    email: admin@superset.com
    password: admin

# PersistentVolumeClaim para almacenar datos
persistence:
  enabled: true
  size: 5Gi
```

Ahora, instala Superset con la configuración personalizada:

```bash
helm install superset superset/superset \
  --namespace data-viz \
  -f values.yaml
```

### Verificar instalación

```bash
kubectl get pods -n data-viz
kubectl get services -n data-viz
```

### Acceder a la UI de Superset

```bash
kubectl port-forward svc/superset 8088:8088 -n data-viz
```

Visita http://localhost:8088 en tu navegador y usa las credenciales:
- Username: admin
- Password: admin

## 2. Configurar Superset para conectarse a Trino

Una vez que accedas a Superset, necesitamos configurar la conexión a Trino para visualizar nuestros datos de Iceberg.

### Instalar dependencias necesarias

Primero, vamos a instalar el paquete de Python necesario para conectar Superset con Trino:

```bash
# Obtener el nombre del pod de Superset
SUPERSET_POD=$(kubectl get pods -n data-viz -l app=superset,component=app -o jsonpath="{.items[0].metadata.name}")

# Instalar el driver de Trino
kubectl exec -it $SUPERSET_POD -n data-viz -- pip install sqlalchemy-trino
```

### Configurar la conexión a Trino

1. En la interfaz de Superset, ve a **Configuraciones > Database Connections**.
2. Haz clic en el botón **+ Database** para agregar una nueva conexión.
3. Completa el formulario con la siguiente información:
   - **Database Name**: Trino Iceberg
   - **SQLAlchemy URI**: `trino://trino@trino.data-lakehouse.svc.cluster.local:8080/iceberg`
   - **Display Name**: Trino Iceberg
   - En la sección **Advanced > Security**:
     - Marca las opciones relevantes según tus necesidades de seguridad
   - En la sección **Advanced > Other**:
     - **CATALOG**: iceberg
     - **SCHEMA**: sales

4. Haz clic en **Test Connection** para verificar la conexión.
5. Haz clic en **Connect** para guardar la conexión.

## 3. Crear un Dashboard en Superset

Ahora, vamos a crear un dashboard para visualizar los datos de ventas en Iceberg.

### Paso 1: Crear un dataset

1. Ve a **Data > Datasets**.
2. Haz clic en **+ Dataset**.
3. Selecciona la base de datos **Trino Iceberg**.
4. Selecciona el esquema **sales**.
5. Selecciona la tabla **transactions** o una consulta join:
   ```sql
   SELECT 
     t.transaction_id,
     p.name,
     p.category,
     t.quantity,
     t.total_amount,
     t.transaction_date
   FROM 
     iceberg.sales.transactions t
   JOIN 
     iceberg.sales.products p ON t.product_id = p.product_id
   ```
6. Asigna un nombre descriptivo a tu dataset, como "Sales Transactions".
7. Haz clic en **Save**.

### Paso 2: Crear gráficos (Charts)

#### Gráfico de barras: Ventas por categoría

1. Ve a **Charts**.
2. Haz clic en **+ Chart**.
3. Selecciona el dataset "Sales Transactions".
4. Selecciona el tipo de visualización "Bar Chart".
5. Configura el gráfico:
   - **Metrics**: SUM(total_amount)
   - **Series**: category
6. Personaliza títulos, etiquetas y colores.
7. Haz clic en **Update Chart**.
8. Guarda el gráfico como "Sales by Category".

#### Gráfico de líneas: Tendencia de ventas

1. Crea un nuevo gráfico.
2. Selecciona el dataset "Sales Transactions".
3. Selecciona el tipo de visualización "Line Chart".
4. Configura el gráfico:
   - **Metrics**: SUM(total_amount)
   - **X-Axis**: transaction_date
   - **Series**: category
5. Personaliza títulos, etiquetas y colores.
6. Haz clic en **Update Chart**.
7. Guarda el gráfico como "Sales Trend".

### Paso 3: Crear el Dashboard

1. Ve a **Dashboards**.
2. Haz clic en **+ Dashboard**.
3. Asigna un nombre descriptivo como "Sales Analysis Dashboard".
4. Haz clic en **Save**.
5. Haz clic en **Edit Dashboard**.
6. Añade los gráficos creados anteriormente arrastrándolos al dashboard.
7. Organiza y ajusta el tamaño de los gráficos.
8. Añade filtros para permitir que los usuarios filtren por fecha, categoría, etc.
9. Haz clic en **Save Changes**.

## 4. Despliegue de Grafana

Ahora, desplegaremos Grafana para crear visualizaciones operacionales y monitorear nuestras herramientas.

### Instalar Grafana con Helm

```bash
# Añadir repositorio de Grafana (si no lo tienes ya)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Instalar Grafana
helm install grafana grafana/grafana \
  --namespace data-viz \
  --set persistence.enabled=true \
  --set persistence.size=2Gi \
  --set adminPassword=admin \
  --set service.type=ClusterIP
```

### Verificar instalación

```bash
kubectl get pods -n data-viz
kubectl get services -n data-viz
```

### Acceder a la UI de Grafana

```bash
kubectl port-forward svc/grafana 3000:80 -n data-viz
```

Visita http://localhost:3000 en tu navegador y usa las credenciales:
- Username: admin
- Password: admin

## 5. Configurar Grafana para visualizar datos operacionales

### Añadir Trino como fuente de datos en Grafana

1. En la interfaz de Grafana, ve a **Configuration > Data Sources**.
2. Haz clic en **Add data source**.
3. Selecciona **PostgreSQL** (Grafana utiliza JDBC para conectarse a Trino, similar a PostgreSQL).
4. Completa la información de conexión:
   - **Name**: Trino
   - **Host**: trino.data-lakehouse.svc.cluster.local:8080
   - **Database**: iceberg
   - **User**: trino
   - **Password**: (dejar en blanco o configurar según sea necesario)
   - **SSL Mode**: disable
   - En la sección **PostgreSQL details**:
     - **Version**: 12
5. Haz clic en **Save & Test** para verificar la conexión.

### Crear un Dashboard operacional en Grafana

#### Panel de rendimiento de Trino

1. Crea un nuevo dashboard.
2. Añade un nuevo panel.
3. Configura la consulta para mostrar el rendimiento de las consultas:
   ```sql
   SELECT 
     query_id,
     query AS query_text,
     user,
     state,
     total_cpu_time_ms/1000 AS cpu_seconds,
     wall_time_ms/1000 AS wall_seconds
   FROM 
     system.runtime.queries
   WHERE 
     state != 'FINISHED'
     OR end_time > now() - interval '1' hour
   ORDER BY 
     created DESC
   LIMIT 100
   ```
4. Configura el panel como una tabla.
5. Guarda el panel como "Current & Recent Queries".

#### Panel de errores en Trino

1. Añade un nuevo panel.
2. Configura la consulta para mostrar los errores:
   ```sql
   SELECT 
     query_id,
     query AS query_text,
     user,
     error_code,
     error_name,
     error_type,
     failure_message
   FROM 
     system.runtime.queries
   WHERE 
     error_code IS NOT NULL
     AND end_time > now() - interval '1' day
   ORDER BY 
     end_time DESC
   LIMIT 50
   ```
3. Configura el panel como una tabla.
4. Guarda el panel como "Query Errors".

#### Panel de uso de memoria de Trino

1. Añade un nuevo panel.
2. Configura la consulta para mostrar el uso de memoria:
   ```sql
   SELECT 
     date_trunc('minute', created) AS minute,
     sum(total_memory_reservation_bytes)/1024/1024 AS total_memory_mb
   FROM 
     system.runtime.queries
   WHERE 
     created > now() - interval '1' day
   GROUP BY 
     date_trunc('minute', created)
   ORDER BY 
     minute
   ```
3. Configura el panel como un gráfico de líneas.
4. Guarda el panel como "Memory Usage Over Time".

### Configurar alertas en Grafana

Puedes configurar alertas en Grafana para notificar cuando ocurran eventos específicos, como:

1. Consultas que tardan más de cierto tiempo.
2. Alta utilización de memoria o CPU.
3. Errores frecuentes en consultas.

Para configurar una alerta:

1. Edita un panel existente.
2. Ve a la pestaña **Alert**.
3. Haz clic en **Create Alert**.
4. Configura las condiciones de la alerta, por ejemplo:
   - **Condition**: WHEN last() OF query(A, 1m, now) IS ABOVE 60
   (Esto se activará cuando una consulta tarde más de 60 segundos)
5. Configura las notificaciones (email, Slack, etc.).
6. Guarda la alerta.

## 6. Integrando ambas herramientas en un flujo de trabajo

### Caso de uso: Pipeline completo de análisis

Ahora que tenemos nuestras herramientas de visualización configuradas, vamos a definir un flujo de trabajo completo:

1. **Ingesta de datos**:
   - Los datos se ingestan en nuestro Data Lakehouse (PostgreSQL -> Airflow -> Kafka -> Iceberg)

2. **Análisis técnico**:
   - Monitoreamos el rendimiento y la salud del sistema con Grafana
   - Detectamos cuellos de botella y optimizamos consultas

3. **Análisis de negocio**:
   - Utilizamos Superset para análisis ad-hoc y descubrimiento de insights
   - Creamos dashboards para diferentes áreas de negocio

4. **Toma de decisiones**:
   - Compartimos los dashboards de Superset con los stakeholders
   - Utilizamos los insights para informar decisiones de negocio

### Ejemplo: Análisis de ventas y optimización técnica

**Escenario**: El equipo de ventas quiere analizar el rendimiento de diferentes categorías de productos, mientras que el equipo técnico necesita garantizar que las consultas sean eficientes.

**Proceso**:

1. El equipo de ventas utiliza Superset para:
   - Visualizar tendencias de ventas por categoría
   - Identificar productos de alto rendimiento
   - Analizar patrones de compra

2. Simultáneamente, el equipo técnico utiliza Grafana para:
   - Monitorear el rendimiento de las consultas
   - Identificar consultas ineficientes
   - Optimizar el sistema de almacenamiento

3. Si se detectan problemas de rendimiento en Grafana:
   - El equipo técnico ajusta la configuración de Trino o Iceberg
   - Optimiza las consultas utilizadas en los dashboards de Superset
   - Ajusta la asignación de recursos en Kubernetes

## Próximos pasos

En el siguiente módulo, profundizaremos en las prácticas de monitoreo y logging para nuestro stack completo de Data Engineering en Kubernetes, complementando lo que hemos aprendido con Grafana. 