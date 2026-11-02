output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.host.id
}

output "ssm_session_command" {
  description = "Open a shell on the host (no SSH, no inbound ports)"
  value       = "aws ssm start-session --target ${aws_instance.host.id} --region ${var.aws_region}"
}

output "bootstrap_log_command" {
  description = "Follow the first-boot provisioning log"
  value       = "aws ssm start-session --target ${aws_instance.host.id} --region ${var.aws_region} --document-name AWS-StartInteractiveCommand --parameters command='sudo tail -f /var/log/ticketstage-bootstrap.log'"
}
