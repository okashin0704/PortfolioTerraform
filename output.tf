output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "ec2_1a_instance_id" {
  value = aws_instance.web_1a.id
}

output "ec2_1c_instance_id" {
  value = aws_instance.web_1c.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.ssm_log_bucket.bucket
}