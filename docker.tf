# configured aws provider with proper credentials
provider "aws" {
  region    = "eu-west-2"
  shared_config_files      = ["/Users/kenna/.aws/conf"]
  shared_credentials_files = ["/Users/kenna/.aws/credentials"]
  profile                  = "Okougwu"
}

# Create a remote backend for your terraform 
terraform {
  backend "s3" {
    bucket = "okougwu-docker-tfstate"
    dynamodb_table = "app-state"
    key    = "LockedID"
    region = "eu-west-2"
    profile = "Okougwu"
  }
}

#Create VPC
resource "aws_vpc" "MyLondonVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  #map_public_ip_on_launch = true
  enable_dns_hostnames = true
  

  tags = {
    Name = "Pro-VPC"
  }
}

#IGW
resource "aws_internet_gateway" "MYIGW" {
  vpc_id = aws_vpc.MyLondonVPC.id

  tags = {
    Name = "London-IGW"
  }
}


#Create Subnet
resource "aws_subnet" "Public-Subnet1" {
  vpc_id     = aws_vpc.MyLondonVPC.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Pub-Sub-1"
  }
}

# create RT
resource "aws_route_table" "My-RT" {
  vpc_id = aws_vpc.MyLondonVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MYIGW.id
  }



  tags = {
    Name = "rt"
  }
}

# RT association
resource "aws_route_table_association" "RT-association" {
  subnet_id      = aws_subnet.Public-Subnet1.id
  route_table_id = aws_route_table.My-RT.id
}

resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 8080 and 22 and 9090"
  vpc_id      = aws_vpc.MyLondonVPC.id

  # allow access on port 8080
  ingress {
    description      = "http proxy access"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # allow access on port 22
  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "http proxy-nginx access"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "http nginx access"
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags   = {
    Name = "Docker server security group"
  }
}

# Use data source to get registered amazon linux ami
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


#launch ec2 install and install website
resource "aws_instance" "server_1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id              = aws_subnet.Public-Subnet1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "nlonKeyPairs"
  user_data            = "${file("docker-install.sh")}"
  

  tags = {
    Name = "Docker-server"
  }
}
