# Virtual Private Gateway (VGW)
resource "aws_vpn_gateway" "cloudlake_vgw" {
  vpc_id          = aws_vpc.cloudlake_core.id
  amazon_side_asn = 64512 # AWS ASN default
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-onpremise-vgw-${var.environment}"
    }
  )
}

# Represents on-premises VPN device
resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65000     # On-premises ASN (use your own ASN)
  ip_address = "209.45.68.65" 
  type       = "ipsec.1"
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-onpremise-cgw-${var.environment}"
    }
  )
}

# This connects the AWS VPG to the on-premises network
resource "aws_vpn_connection" "vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.cloudlake_vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"

  static_routes_only = true

  # Tunnel options with the inside IP CIDR for both tunnels
  tunnel1_inside_cidr  = "169.254.16.56/30"
  tunnel2_inside_cidr  = "169.254.21.36/30"

  # Tunnel pre-shared keys (PSK) for both tunnels
  tunnel1_preshared_key = var.preshared_key_1
  tunnel2_preshared_key = var.preshared_key_2

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpn-connection-${var.environment}"
    }
  )
}

