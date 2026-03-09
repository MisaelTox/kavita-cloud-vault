variable "aws_region" {
  description = "AWS region where Kavita will be deployed"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "kavita-cloud-vault"
}

variable "timezone" {
  description = "Timezone for the Kavita container (e.g. America/Mexico_City)"
  type        = string
  default     = "America/Mexico_City"
}