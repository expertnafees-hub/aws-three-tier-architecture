# -----------------------------------------------------------------------------
# 1. ROUTE 53 HOSTED ZONE LOOKUP (Optional / Conditional)
# -----------------------------------------------------------------------------
data "aws_route53_zone" "primary" {
  count        = var.enable_custom_domain ? 1 : 0
  name         = var.domain_name
  private_zone = false

  lifecycle {
    precondition {
      condition     = trimspace(var.domain_name) != "" && !endswith(var.domain_name, ".")
      error_message = "Custom-domain mode requires a nonempty hosted-zone/domain name without a trailing dot."
    }
  }
}

# -----------------------------------------------------------------------------
# 2. AWS CERTIFICATE MANAGER (ACM) PUBLIC SSL/TLS CERTIFICATE
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "cert" {
  count             = var.enable_custom_domain ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name    = "${var.project_name}-acm-cert"
    Managed = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# 3. ROUTE 53 DNS VALIDATION RECORD
# -----------------------------------------------------------------------------
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary[0].zone_id
}

# -----------------------------------------------------------------------------
# 4. ACM CERTIFICATE VALIDATION HANDSHAKE
# -----------------------------------------------------------------------------
resource "aws_acm_certificate_validation" "cert" {
  count                   = var.enable_custom_domain ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# 5. ROUTE 53 ALIAS RECORD (Directs custom domain to ALB DNS)
# -----------------------------------------------------------------------------
resource "aws_route53_record" "alb_alias" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
