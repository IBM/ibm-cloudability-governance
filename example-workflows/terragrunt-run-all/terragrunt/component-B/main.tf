provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "my_instance" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = t2.micro

  tags = {
    Component = var.component_name
  }
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.component_name}-bucket"
  
  tags = {
    Component = var.component_name
  }
}
