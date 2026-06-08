variable "db_password" {
  description = "The password for the RDS MySQL database."
  type        = string
  sensitive   = true # Mark as sensitive so Terraform doesn't print it in logs
}
