output "public_ip" {
  description = "Elastic IP of the instance (your URL host)"
  value       = aws_eip.app.public_ip
}

output "app_url" {
  description = "Open this once the stack is up"
  value       = "http://${aws_eip.app.public_ip}"
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh ubuntu@${aws_eip.app.public_ip}"
}

output "instance_id" {
  description = "Use it to start/stop the box between demos"
  value       = aws_instance.app.id
}
