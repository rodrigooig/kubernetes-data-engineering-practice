# Kubernetes for Data Engineering

Este proyecto educativo está diseñado para aprender Kubernetes en el contexto de Data Engineering a través de ejercicios prácticos y progresivos.

## Estructura del Proyecto

El proyecto está organizado en los siguientes módulos:

1. **[Introducción a Kubernetes](./01-introduccion/README.md)**
   - Conceptos básicos de Kubernetes
   - Relevancia en Data Engineering
   
2. **[Configuración del Entorno](./02-configuracion/README.md)**
   - Instalación de herramientas
   - Configuración de cluster local
   
3. **[Despliegue de Aplicaciones Básicas](./03-aplicaciones-basicas/README.md)**
   - [Pods](./03-aplicaciones-basicas/ejemplos/pod/nginx-pod.yaml), [Deployments](./03-aplicaciones-basicas/ejemplos/deployment/nginx-deployment.yaml) y [Services](./03-aplicaciones-basicas/ejemplos/service/nginx-service.yaml)
   - [ConfigMaps](./03-aplicaciones-basicas/ejemplos/configmap/nginx-config.yaml) y [Secrets](./03-aplicaciones-basicas/ejemplos/secret/db-secret.yaml)
   - [Ejercicio práctico](./03-aplicaciones-basicas/ejemplos/ejercicio/) de comunicación entre servicios
   
4. **[Data Pipeline en Kubernetes](./04-data-pipeline/README.md)**
   - [Apache Airflow en Kubernetes](./04-data-pipeline/manifests/airflow-values.yaml)
   - [Kafka Cluster](./04-data-pipeline/manifests/kafka-cluster.yaml) para streaming
   - [DAGs de ejemplo](./04-data-pipeline/manifests/dags-configmap.yaml) para ETL
   - [Consumer de Kafka](./04-data-pipeline/manifests/kafka-consumer.yaml) para procesamiento
   
5. **[Data Lakehouse con Iceberg y Trino](./05-data-lakehouse/README.md)**
   - [Despliegue de MinIO](./05-data-lakehouse/manifests/minio-values.yaml) (almacenamiento compatible con S3)
   - [Hive Metastore](./05-data-lakehouse/manifests/hive-metastore-values.yaml) para gestión de metadatos
   - [Despliegue de Trino](./05-data-lakehouse/manifests/trino-values.yaml) como motor de consulta
   - [Script de inicialización](./05-data-lakehouse/manifests/init-sample-data.sh) para datos de ejemplo
   
6. **[Visualización y Análisis](./06-visualizacion/README.md)**
   - [Apache Superset](./06-visualizacion/manifests/superset-values.yaml) para dashboards
   - [Grafana](./06-visualizacion/manifests/grafana-values.yaml) para monitoreo
   
7. **[Monitoreo y Logging](./07-monitoreo/README.md)**
   - [Prometheus Stack](./07-monitoreo/manifests/prometheus-values.yaml) para métricas
   - [ELK Stack](./07-monitoreo/manifests/elasticsearch-values.yaml) para logs centralizados
   - [Dashboards de ejemplo](./07-monitoreo/manifests/kafka-dashboard.json) para monitoreo
   - [Exporters](./07-monitoreo/manifests/trino-exporter.yaml) para componentes del data stack
   
8. **[Ejercicios Prácticos y Desafíos](./08-ejercicios/README.md)**
   - **Ejercicio 1**: [Despliegue manual](./08-ejercicios/ejercicio-01/) de PostgreSQL
   - **Ejercicio 2**: [Gestión de recursos](./08-ejercicios/ejercicio-02/) para workloads de ML
   - **Ejercicio 3**: [Auto-escalado](./08-ejercicios/ejercicio-03/) de servicios
   - **Ejercicio 4**: [Pipeline de datos](./08-ejercicios/ejercicio-04/) con CronJobs
   - **Ejercicio 5**: [StatefulSets](./08-ejercicios/ejercicio-05/) para bases de datos distribuidas

## Requisitos Previos

- Conocimientos básicos de Docker
- Familiaridad con conceptos de Data Engineering
- Computadora con al menos 8GB de RAM y 20GB de espacio libre
- Minikube, kind o k3d para cluster local
- kubectl instalado

## Cómo Empezar

1. Clona este repositorio:
   ```bash
   git clone https://github.com/rodrigooig/kubernetes-data-engineering-practice.git
   cd kubernetes-data-engineering-practice
   ```

2. Sigue las instrucciones en el directorio [`01-introduccion`](./01-introduccion/README.md) para comenzar tu viaje de aprendizaje con Kubernetes para Data Engineering.

3. Avanza progresivamente por cada módulo, siguiendo los READMEs respectivos y aplicando los manifiestos YAML con `kubectl apply -f <archivo.yaml>`.

## Recursos Adicionales

Consulta el directorio [`recursos-adicionales`](./recursos-adicionales/README.md) para encontrar enlaces, libros y cursos recomendados para profundizar en Kubernetes y Data Engineering.

## Contribuciones

Las contribuciones son bienvenidas. Si encuentras errores o quieres mejorar el contenido, por favor envía un pull request o abre un issue.

## Licencia

Este proyecto está licenciado bajo la licencia MIT - ver el archivo LICENSE para más detalles. 