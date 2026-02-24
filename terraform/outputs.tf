output "kavita_public_ip" {
  description = "IP pública del servidor de Kavita. Úsala con el puerto 5000."
  value       = "Accede a tu servidor en: http://${aws_ecs_service.kavita_service.name}.la-ip-la-veras-en-la-consola-ecs"
  # Nota técnica: Obtener la IP dinámica de Fargate directamente en Terraform 
  # es un poco complejo sin un Load Balancer, pero te enseñaré a verla 
  # rápido con un comando de AWS CLI o desde la consola.
}

output "efs_id" {
  description = "ID del sistema de archivos EFS"
  value       = aws_efs_file_system.kavita_storage.id
}