#!/bin/bash

set -e
exec > /var/log/user_data.log 2>&1

echo "Actualizando el sistema..."
apt-get update -y && apt-get upgrade -y

echo "Instalando dependencias..."
apt-get install -y curl unzip apt-transport-https ca-certificates gnupg lsb-release

echo "Instalando AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

echo "Instalando kubectl..."
curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.2/2023-03-17/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl

echo "Instalando eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin

echo "Instalando Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

echo "Instalando Docker Compose..."
curl -fsSL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Instalando Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Creando el cluster..."
sudo -u ubuntu eksctl create cluster \
  --name "mundose" \
  --region us-east-1 \
  --node-type t3.small \
  --nodes 3 \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ubuntu \
  --managed \
  --full-ecr-access \
  --zones us-east-1a,us-east-1b,us-east-1c \
  > /var/log/cluster_info.log 2>&1

echo "Creando pod de prueba..."
sudo -u ubuntu kubectl run nginx --image=nginx --port=80
sudo -u ubuntu kubectl expose pod nginx --type=LoadBalancer --port=80
sudo -u ubuntu kubectl get svc nginx > /var/log/nginx_svc.log 2>&1