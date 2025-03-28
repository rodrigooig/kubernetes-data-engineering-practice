# Configuración del Entorno Kubernetes

En este módulo, configuraremos un entorno local de Kubernetes para nuestros ejercicios de Data Engineering.

## Herramientas necesarias

Instalaremos las siguientes herramientas:

1. **Docker**: Motor de contenedores
2. **Minikube**: Cluster Kubernetes local
3. **kubectl**: CLI para interactuar con Kubernetes
4. **Helm**: Gestor de paquetes para Kubernetes

## Instalación

### Docker

Docker es la base para ejecutar contenedores. Sigue las instrucciones según tu sistema operativo:

#### macOS

```bash
# Instalar Homebrew si no lo tienes
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Docker Desktop
brew install --cask docker
```

#### Linux (Ubuntu/Debian)

```bash
# Actualizar repositorios
sudo apt-get update

# Instalar dependencias
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Añadir clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Añadir repositorio de Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Añadir usuario al grupo docker (evita usar sudo)
sudo usermod -aG docker $USER
newgrp docker
```

#### Windows

1. Descargar e instalar [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Asegurarse de habilitar WSL 2 durante la instalación
3. Reiniciar el sistema después de la instalación

### Minikube

Minikube nos permite ejecutar un cluster Kubernetes de un solo nodo en nuestra máquina local.

#### macOS

```bash
# Instalar mediante Homebrew
brew install minikube
```

#### Linux

```bash
# Descargar e instalar minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

#### Windows

```bash
# Instalar mediante Chocolatey
choco install minikube
```

### kubectl

kubectl es la herramienta de línea de comandos para interactuar con el cluster Kubernetes.

#### macOS

```bash
# Instalar mediante Homebrew
brew install kubectl
```

#### Linux

```bash
# Descargar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Hacerlo ejecutable y moverlo al PATH
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### Windows

```bash
# Instalar mediante Chocolatey
choco install kubernetes-cli
```

### Helm

Helm es el gestor de paquetes para Kubernetes, nos ayudará a instalar aplicaciones complejas.

#### macOS

```bash
# Instalar mediante Homebrew
brew install helm
```

#### Linux

```bash
# Descargar e instalar Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
```

#### Windows

```bash
# Instalar mediante Chocolatey
choco install kubernetes-helm
```

## Iniciar Minikube

Ahora iniciaremos nuestro cluster Kubernetes local:

```bash
# Iniciar Minikube con más recursos para soportar aplicaciones de data
minikube start --cpus 4 --memory 8192 --disk-size 30g
```

## Verificar la instalación

Comprueba que todo está funcionando correctamente:

```bash
# Verificar la versión de kubectl
kubectl version --client

# Verificar que minikube está funcionando
minikube status

# Verificar conexión con el cluster
kubectl get nodes
```

Deberías ver un nodo (el de minikube) en estado "Ready".

## Dashboard de Kubernetes

Kubernetes proporciona un dashboard web que podemos utilizar para visualizar el estado del cluster:

```bash
# Iniciar el dashboard
minikube dashboard
```

Esto abrirá automáticamente el dashboard en tu navegador.

## Configuración del entorno para Helm

Añadamos algunos repositorios Helm comunes que usaremos más adelante:

```bash
# Añadir repositorio de Bitnami (contiene muchas aplicaciones útiles)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Añadir repositorio de Apache Airflow
helm repo add apache-airflow https://airflow.apache.org

# Actualizar repositorios
helm repo update
```

## Próximos pasos

Una vez que hayas configurado el entorno, estamos listos para comenzar con el despliegue de nuestras primeras aplicaciones en Kubernetes. En el siguiente módulo, aprenderemos a desplegar aplicaciones básicas.

## Solución de problemas comunes

### Insuficiente RAM o CPU

Si encuentras errores debido a recursos insuficientes, puedes detener minikube y reiniciarlo con más recursos:

```bash
minikube stop
minikube start --cpus 4 --memory 8192 --disk-size 30g
```

### Problemas con Docker en Windows

Si encuentras problemas con Docker en Windows, asegúrate de:
1. Tener WSL 2 habilitado
2. Reiniciar tu equipo después de la instalación
3. Tener habilitada la virtualización en la BIOS

### Error "kubectl unable to connect"

Si no puedes conectarte al cluster, verifica:

```bash
# Revisar el estado de minikube
minikube status

# Si está detenido, iniciarlo
minikube start

# Verificar la configuración de kubectl
kubectl config view
``` 