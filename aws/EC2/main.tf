data "aws_ssm_parameter" "aws_credentials" {
  name = "/my-app/aws-credentials"
}

locals {
  aws_credentials = jsondecode(data.aws_ssm_parameter.aws_credentials.value)
}


resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_instance" "ubuntu_server" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "ubuntu"
  security_groups = [aws_security_group.ec2_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user_data.log 2>&1  # Redirigir la salida del script a un log

              echo "Configurando credenciales de AWS..."
              mkdir -p /home/ubuntu/.aws
              cat <<EOT > /home/ubuntu/.aws/credentials
              [default]
              aws_access_key_id = ${local.aws_credentials["AWS_ACCESS_KEY_ID"]}
              aws_secret_access_key = ${local.aws_credentials["AWS_SECRET_ACCESS_KEY"]}
              region = ${local.aws_credentials["AWS_DEFAULT_REGION"]}
              EOT
              chown -R ubuntu:ubuntu /home/ubuntu/.aws

              echo "Ejecutando user_data.sh..."
              cat <<'EOT' > /tmp/user_data.sh
              ${templatefile("${path.module}/user_data.sh", {DOCKER_COMPOSE_VERSION = "2.33.1"})}
              EOT

              chmod +x /tmp/user_data.sh
              /bin/bash /tmp/user_data.sh
              EOF

  tags = {
    Name = "UbuntuServer"
  }
}

