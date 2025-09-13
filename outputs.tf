output "proxy_instance_id" { value = aws_instance.proxy.id }
output "proxy_private_ip" { value = aws_instance.proxy.private_ip }
output "proxy_eip" { value = try(aws_eip.proxy[0].public_ip, "") }

output "app_instance_id" { value = aws_instance.app.id }
output "app_private_ip" { value = aws_instance.app.private_ip }

output "db_instance_id" { value = aws_instance.db.id }
output "db_private_ip" { value = aws_instance.db.private_ip }
