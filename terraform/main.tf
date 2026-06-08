# Configure the AWS provider
provider "aws" {
  region = "us-east-1" # Choose your desired AWS region
}

# --- VPC (Virtual Private Cloud) ---
resource "aws_vpc" "piano_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "piano-teaching-vpc"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "piano_igw" {
  vpc_id = aws_vpc.piano_vpc.id
  tags = {
    Name = "piano-teaching-igw"
  }
}

# --- Public Subnet ---
resource "aws_subnet" "piano_public_subnet" {
  vpc_id            = aws_vpc.piano_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Choose an AZ within your region
  map_public_ip_on_launch = true # Automatically assign public IPs to instances in this subnet
  tags = {
    Name = "piano-public-subnet"
  }
}

# --- Private Subnet ---
resource "aws_subnet" "piano_private_subnet" {
  vpc_id            = aws_vpc.piano_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a" # Choose an AZ within your region
  tags = {
    Name = "piano-private-subnet"
  }
}

# --- Public Route Table ---
resource "aws_route_table" "piano_public_rt" {
  vpc_id = aws_vpc.piano_vpc.id
  tags = {
    Name = "piano-public-route-table"
  }
}

resource "aws_route" "piano_public_internet_route" {
  route_table_id         = aws_route_table.piano_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.piano_igw.id
}

resource "aws_route_table_association" "piano_public_subnet_association" {
  subnet_id      = aws_subnet.piano_public_subnet.id
  route_table_id = aws_route_table.piano_public_rt.id
}

# --- Private Route Table (for RDS - no direct internet access) ---
resource "aws_route_table" "piano_private_rt" {
  vpc_id = aws_vpc.piano_vpc.id
  tags = {
    Name = "piano-private-route-table"
  }
}

resource "aws_route_table_association" "piano_private_subnet_association" {
  subnet_id      = aws_subnet.piano_private_subnet.id
  route_table_id = aws_route_table.piano_private_rt.id
}


# --- Security Group for EC2 (Web Server) ---
resource "aws_security_group" "piano_web_sg" {
  name        = "piano-web-sg"
  description = "Allow HTTP/HTTPS/SSH traffic to web server"
  vpc_id      = aws_vpc.piano_vpc.id

  # Allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic from anywhere (if you implement SSL later)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic from your IP (replace with your public IP for better security)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: This allows SSH from anywhere. Replace with your actual public IP, e.g., ["YOUR_PUBLIC_IP/32"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "piano-web-sg"
  }
}

# --- Security Group for RDS (Database) ---
resource "aws_security_group" "piano_db_sg" {
  name        = "piano-db-sg"
  description = "Allow MySQL traffic from web server"
  vpc_id      = aws_vpc.piano_vpc.id

  # Allow MySQL traffic from the web server security group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.piano_web_sg.id]
  }

  # No direct outbound internet access for the DB
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # This allows all outbound, consider restricting to only necessary services later
  }

  tags = {
    Name = "piano-db-sg"
  }
}

# --- EC2 Instance (Web Server) ---
resource "aws_instance" "piano_web_server" {
  ami           = "ami-053b0d53c27922dcd" # Ubuntu Server 20.04 LTS (HVM), SSD Volume Type, us-east-1. FIND LATEST AMI FOR YOUR REGION!
  instance_type = "t2.micro"              # Free tier eligible
  subnet_id     = aws_subnet.piano_public_subnet.id
  security_groups = [aws_security_group.piano_web_sg.id]
  key_name      = aws_key_pair.piano_ssh_key.key_name # Referencing the key pair created below

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y apache2 php libapache2-mod-php php-mysql
              sudo systemctl start apache2
              sudo systemctl enable apache2
              # Copy website files (assuming they are placed in /var/www/html later)
              sudo rm /var/www/html/index.html
              # Placeholder for copying actual website files. You'll do this manually or via SCP after creation.
              echo "<h1>Welcome to Piano Teaching Website!</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "piano-web-server"
  }
}

# --- SSH Key Pair for EC2 ---
resource "aws_key_pair" "piano_ssh_key" {
  key_name   = "piano-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub") # Adjust path to your public SSH key. Generate if you don't have one!
                                          # Use `ssh-keygen -t rsa -b 4096` to generate
}

# --- RDS MySQL Database ---
resource "aws_db_subnet_group" "piano_db_subnet_group" {
  name       = "piano-db-subnet-group"
  subnet_ids = [aws_subnet.piano_private_subnet.id]
  tags = {
    Name = "piano-db-subnet-group"
  }
}

resource "aws_db_instance" "piano_db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.35" # Specify a consistent version, check available versions
  instance_class       = "db.t2.micro" # Free tier eligible
  identifier           = "piano-teaching-db"
  username             = "admin"
  password             = var.db_password # Use a variable for sensitive data
  db_subnet_group_name = aws_db_subnet_group.piano_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.piano_db_sg.id]
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true # Set to false in production for backups
  multi_az             = false # Set to true in production for high availability
  publicly_accessible  = false # Crucial for security: DB should NOT be publicly accessible

  tags = {
    Name = "piano-teaching-db"
  }
}
