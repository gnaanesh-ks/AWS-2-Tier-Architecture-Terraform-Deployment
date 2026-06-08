output "website_public_ip" {
  description = "The public IP address of the EC2 web server."
  value       = aws_instance.piano_web_server.public_ip
}

output "rds_endpoint" {
  description = "The endpoint address of the RDS MySQL database."
  value       = aws_db_instance.piano_db.address
}

output "rds_username" {
  description = "The username for the RDS MySQL database."
  value       = aws_db_instance.piano_db.username
}
