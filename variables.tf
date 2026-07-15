variable "aws_region" {
  description = "AWS region — Learner Lab is scoped to us-east-1"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "weatherwatch"
}

variable "lab_role_name" {
  description = "Name of the pre-existing Learner Lab execution role"
  type        = string
  default     = "LabRole"
}

# The Secrets Manager secret created in Phase 1 (Session 3). Referenced here,
# never recreated — its value is set out of band and never touches Terraform.
variable "secret_name" {
  description = "Name of the existing Secrets Manager secret holding the API key"
  type        = string
  default     = "weatherwatch/openweathermap-api-key"
}

# The on-demand DynamoDB table created in Phase 0. The handler writes results
# here. Referenced by name; the table itself is owned by the phase0 state.
variable "table_name" {
  description = "Name of the existing DynamoDB table to store results in"
  type        = string
  default     = "weatherwatch-datastore"
}

variable "default_city" {
  description = "City used when the request has no ?city= query parameter"
  type        = string
  default     = "London"
}
