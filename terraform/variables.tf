variable "aws_region" {
  description = "Región de AWS donde se desplegará Kavita"
  type        = string
  default     = "eu-north-1" # Cámbiala por la que prefieras
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "kavita-cloud-vault"
}

variable "timezone" {
  description = "Zona horaria para el contenedor"
  type        = string
  default     = "America/Mexico_City"
}