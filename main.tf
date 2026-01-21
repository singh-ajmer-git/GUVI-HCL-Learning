#VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ubuntu-vpc"
  }
}

resource "aws_vpc" "main-south" {
  provider = aws.ap-south-1
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ubuntu-vpc"
  }
}

# Subnet

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "public-south" {
  depends_on = [ aws_vpc.main-south ]
  provider = aws.ap-south-1
  vpc_id                  = aws_vpc.main-south.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_internet_gateway" "igw-south" {
  provider = aws.ap-south-1
  vpc_id = aws_vpc.main-south.id
}


# Route Table

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "rt-south" {
  vpc_id = aws_vpc.main-south.id
  provider = aws.ap-south-1

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-south.id
  }
}


resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta-south" {
  depends_on = [ aws_vpc.main-south ]
  provider = aws.ap-south-1
  subnet_id      = aws_subnet.public-south.id
  route_table_id = aws_route_table.rt-south.id
}

# Security Group (SSH)

resource "aws_security_group" "ssh" {
  name   = "ssh-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh-south" {
  depends_on = [ aws_vpc.main-south ]
  name   = "ssh-sg-south"
  vpc_id = aws_vpc.main-south.id
  provider = aws.ap-south-1

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "west" {
  provider   = aws.ap-south-1
  key_name   = "guvi-test"
  public_key = file("${path.module}/guvi-test.pub")
}



# Ubuntu EC2 Instance

resource "aws_instance" "ubuntu" {
  ami                    = "ami-00f46ccd1cbfb363e"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh.id]

    key_name = "guvi-test"

  tags = {
    Name = "Ubuntu-EC2"
  }
}

resource "aws_instance" "ubuntu-south" {
  provider = aws.ap-south-1
  ami                    = "ami-019715e0d74f695be" 
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-south.id
  vpc_security_group_ids = [aws_security_group.ssh-south.id]

  
  key_name = "guvi-test"

  tags = {
    Name = "Ubuntu-EC2"
  }
}


# Output

output "public_ip" {
  value = aws_instance.ubuntu.public_ip
}

output "public_ip-south" {
  value = aws_instance.ubuntu-south.public_ip
}