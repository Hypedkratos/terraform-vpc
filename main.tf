# Define the provider (AWS)
provider "aws" {
  region = "us-east-1"
}

# Creating a VPC in AWS cloud
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "MainVPC"
  }
}

# Creating a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a" # Replace with your desired AZ
  tags = {
    Name = "PublicSubnet"
  }
}

# Creating an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MainInternetGateway"
  }
}

# Creating a route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MainRouteTable"
  }
}

# Adding a route to the route table
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associating the subnet with the route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.main.id
}

# Creating a security group to allow HTTP access
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  name   = "web_sg"

  ingress {
    description      = "Allow HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebSecurityGroup"
  }
}

# Creating a key pair for EC2
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer_key"
  public_key = tls_private_key.key.public_key_openssh
}

# Writing the private key to a file
resource "local_file" "private_key" {
  filename = "deployer_key.pem"
  content  = tls_private_key.key.private_key_pem
}

# Creating an EC2 instance
resource "aws_instance" "web_server" {
  ami           = "ami-0c02fb55956c7d316" # Replace with the latest Amazon Linux AMI ID for your region
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [
    aws_security_group.web_sg.name
  ]
  key_name = aws_key_pair.deployer_key.key_name

  # User data to upload index.html and set up HTTP server
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "<h1>Welcome to My Web Server</h1>" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "WebServer"
  }
}

# Output the public IP of the EC2 instance
output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}

