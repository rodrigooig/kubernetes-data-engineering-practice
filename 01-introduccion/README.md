# Introducción a Kubernetes para Data Engineering

## ¿Qué es Kubernetes?

Kubernetes (K8s) es una plataforma de código abierto para la automatización del despliegue, escalado y gestión de aplicaciones en contenedores. Originalmente desarrollado por Google, ahora mantenido por la Cloud Native Computing Foundation (CNCF).

## ¿Por qué Kubernetes es relevante para Data Engineering?

El Data Engineering moderno enfrenta varios desafíos:

- **Complejidad de infraestructura**: Los pipelines de datos incluyen múltiples componentes (ingestión, procesamiento, almacenamiento).
- **Escalabilidad**: Necesidad de escalar recursos bajo demanda para procesamiento de datos.
- **Alta disponibilidad**: Los pipelines deben ser resilientes a fallos.
- **Consistencia**: Entornos de desarrollo, prueba y producción deben ser coherentes.

Kubernetes resuelve estos desafíos proporcionando:

- **Orquestación centralizada**: Gestión unificada de todos los componentes del stack de datos.
- **Auto-escalado**: Ampliación automática de recursos según la carga.
- **Auto-reparación**: Reinicio automático de componentes con fallos.
- **Portabilidad**: Ejecución del mismo stack en cualquier plataforma que soporte Kubernetes.

## Conceptos básicos de Kubernetes

### Arquitectura

![Arquitectura Kubernetes](https://d33wubrfki0l68.cloudfront.net/2475489eaf20163ec0f54ddc1d92aa8d4c87c96b/e7c81/images/docs/components-of-kubernetes.svg)

Kubernetes utiliza una arquitectura cliente-servidor:

- **Master Node**: Controla el cluster (API Server, Scheduler, Controller Manager, etcd)
- **Worker Nodes**: Ejecutan las cargas de trabajo (kubelet, kube-proxy, Container Runtime)

### Componentes clave

#### Pods

El Pod es la unidad más pequeña y fundamental en Kubernetes. Representa un proceso en ejecución en el cluster y encapsula:

- Uno o más contenedores
- Almacenamiento compartido
- Networking compartido (IP única)
- Especificaciones de ejecución

En Data Engineering, un pod puede representar:
- Un procesador de datos Spark
- Un nodo de Apache Kafka
- Un worker de Airflow

#### Deployments

Los Deployments gestionan la creación y actualización de réplicas de Pods:

- Garantizan el número deseado de réplicas
- Proporcionan actualizaciones sin tiempo de inactividad
- Permiten rollbacks a versiones anteriores

Ejemplos en Data Engineering:
- Despliegue de múltiples workers de procesamiento
- Múltiples instancias de un servicio de metadatos

#### Services

Los Services proporcionan una abstracción para acceder a un conjunto de Pods:

- IP estable y nombre DNS
- Balanceo de carga entre Pods
- Descubrimiento de servicios

Ejemplos en Data Engineering:
- Endpoint estable para una base de datos
- Interfaz de acceso a una API de datos

#### Volúmenes persistentes

Los volúmenes proporcionan almacenamiento persistente para los Pods:

- Almacenamiento independiente del ciclo de vida del Pod
- Múltiples opciones (local, NFS, cloud storage)

Críticos en Data Engineering para:
- Almacenamiento de datos procesados
- Almacenamiento de estado para servicios stateful como bases de datos

#### ConfigMaps y Secrets

Permiten separar la configuración del código:

- ConfigMaps: Datos de configuración no sensibles
- Secrets: Datos sensibles (contraseñas, tokens)

Esenciales para:
- Configuración de conexiones a bases de datos
- Almacenamiento de credenciales para servicios externos

## Cómo Kubernetes mejora los workflows de Data Engineering

1. **Consistencia entre entornos**: Misma infraestructura en desarrollo y producción
2. **Aislamiento de recursos**: Garantiza que cada componente tenga los recursos necesarios
3. **Despliegue simplificado**: CI/CD para pipelines de datos
4. **Resiliencia**: Auto-reparación de componentes fallidos
5. **Gestión de estado**: Crucial para componentes stateful como bases de datos

## Próximos pasos

En el siguiente módulo, configuraremos un entorno Kubernetes local para comenzar a practicar estos conceptos.

## Ejercicio práctico

Antes de avanzar, familiarízate con los siguientes comandos de Kubernetes ejecutándolos una vez que hayamos configurado el cluster:

```bash
# Ver nodos del cluster
kubectl get nodes

# Ver todos los pods en el namespace default
kubectl get pods

# Ver todos los servicios
kubectl get services

# Ver información detallada de un pod
kubectl describe pod [nombre-del-pod]
``` 