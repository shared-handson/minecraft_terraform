## それぞれに 0.0.0.0/0 → NAT インスタンス を追加
#resource "aws_route" "private_default_to_nat" {
#  for_each               = toset(var.private_route_table_ids)
#  route_table_id         = each.value
#  destination_cidr_block = "0.0.0.0/0"
#  instance_id            = aws_instance.nat.id
#
#  depends_on = [aws_instance.nat]
#}
resource "aws_route" "private_default_to_nat" {
  for_each               = toset(var.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"

  # ← ここが重要：ENIを指定
  network_interface_id = aws_instance.nat.primary_network_interface_id

  depends_on = [aws_instance.nat]
}
