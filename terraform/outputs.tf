output "kavita_public_ip" {
  description = "Kavita server access info. Find the public IP in the ECS console."
  value       = "Access your server at: http://<ECS-TASK-PUBLIC-IP>:5000"
  # Note: Fargate dynamic IPs cannot be retrieved directly via Terraform without a Load Balancer.
  # Use the AWS CLI or ECS console to find the assigned public IP after deployment.
}

output "efs_id" {
  description = "EFS file system ID used for persistent Kavita storage"
  value       = aws_efs_file_system.kavita_storage.id
}