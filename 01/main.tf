# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr_block
}

# SUBNETS
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet1_cidr_block
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet2_cidr_block
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# INTERNET GATEWAY & ROUTE TABLE-INTERNET GATEWAY ASSOCIATION
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# ROUTE TABLE-SUBNETS ASSOCIATION
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.RT.id
}

# SECURITY GROUP
resource "aws_security_group" "websg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
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

  tags = {
    Name = "web-sg"
  }
}

# S3 BUCKET
resource "aws_s3_bucket" "example" {
  bucket = "terraform-demo-ruzny447qnds.com"
}

# EC2 INSTANCES
resource "aws_instance" "webserver1" {
  ami             = "ami-0c7217cdde317cfec"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.websg.id]
  subnet_id       = aws_subnet.subnet1.id
  user_data       = base64encode(file("userdata1.sh"))
}

resource "aws_instance" "webserver2" {
  ami             = "ami-0c7217cdde317cfec"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.websg.id]
  subnet_id       = aws_subnet.subnet2.id
  user_data       = base64encode(file("userdata2.sh"))
}

# APPLICATION LOAD BALANCER
resource "aws_lb" "myalb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]
  subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "my-alb"
  }
}

# TARGET GROUPS
resource "aws_lb_target_group" "mytg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# TARGET GROUP ATTACHMENTS
resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.mytg.id
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachment2" {
  target_group_arn = aws_lb_target_group.mytg.id
  target_id        = aws_instance.webserver2.id
  port             = 80
}

# LISTENER
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mytg.arn
    type             = "forward"
  }
}

# OUTPUT
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}
