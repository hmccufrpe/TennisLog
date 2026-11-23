variable "aws_region" {
  description = "AWS region for every resource (Learner Lab allows us-east-1 and us-west-2)."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix and Project tag."
  type        = string
  default     = "tennislog"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the application hosts."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of application instances behind the ALB (spread over 2 AZs)."
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "tennislog"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "tennislog"
}

variable "create_iam_resources" {
  description = "false (default): reuse the existing instance profile, as in AWS Academy Learner Lab where IAM creation is blocked. true: create the least-privilege role in iam.tf."
  type        = bool
  default     = false
}

variable "instance_profile_name" {
  description = "Existing instance profile attached to the hosts when create_iam_resources = false."
  type        = string
  default     = "LabInstanceProfile"
}
