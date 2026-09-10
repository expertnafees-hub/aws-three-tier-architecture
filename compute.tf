# -----------------------------------------------------------------------------
# 1. LATEST AMAZON LINUX 2023 AMI DATA SOURCE
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# 2. EC2 LAUNCH TEMPLATE (Tier 2 Compute Blueprint)
# -----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" # AWS Modern Nitro Architecture (Free Tier Eligible)

  # Network Interface: Public IP for software download, chained SG for security
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app.id]
  }

  # Enforce IMDSv2 (Blocks SSRF Metadata Attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Hardened User Data script with IMDSv2 dynamic token lookup
  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -euo pipefail

              dnf update -y
              dnf install -y nginx
              systemctl start nginx
              systemctl enable nginx

              # IMDSv2 Token Retrieval
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
              PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

              cat <<HTML > /usr/share/nginx/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <title>Production 3-Tier Architecture</title>
                <style>
                  body { font-family: monospace; background: #070A0F; color: #E6EDF3; padding: 40px; text-align: center; }
                  .card { background: #0D1117; border: 1px solid #30363D; border-radius: 12px; padding: 32px; max-width: 650px; margin: auto; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
                  .highlight { color: #FF9900; font-weight: bold; }
                  .cyan { color: #22D3EE; font-weight: bold; }
                  .badge { display: inline-block; background: #238636; color: #fff; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: bold; margin-bottom: 16px; }
                  .metric-row { display: flex; justify-content: space-between; border-bottom: 1px solid #21262D; padding: 10px 0; font-size: 14px; }
                  .metric-label { color: #8B949E; }
                </style>
              </head>
              <body>
                <div class="card">
                  <span class="badge">● TIER 2 COMPUTE ACTIVE</span>
                  <h2>🚀 Production AWS 3-Tier Architecture</h2>
                  <p style="color: #8B949E;">Engineered by: <span class="highlight">Nafees Ur Rehman</span></p>
                  
                  <div style="margin-top: 24px; text-align: left;">
                    <div class="metric-row">
                      <span class="metric-label">Instance ID:</span>
                      <span class="cyan">$INSTANCE_ID</span>
                    </div>
                    <div class="metric-row">
                      <span class="metric-label">Availability Zone:</span>
                      <span class="highlight">$AVAILABILITY_ZONE</span>
                    </div>
                    <div class="metric-row">
                      <span class="metric-label">Private IPv4:</span>
                      <span>$PRIVATE_IP</span>
                    </div>
                    <div class="metric-row">
                      <span class="metric-label">Routing Tier:</span>
                      <span>Application Load Balancer (Tier 1)</span>
                    </div>
                    <div class="metric-row">
                      <span class="metric-label">Database Tier:</span>
                      <span>Multi-AZ RDS MySQL (Tier 3 Isolated)</span>
                    </div>
                  </div>

                  <p style="font-size: 11px; color: #8B949E; margin-top: 24px;">Refresh this browser tab to watch the ALB alternate across Availability Zones!</p>
                </div>
              </body>
              </html>
              HTML
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-node"
      Tier = "Tier2-App"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# 3. AUTO SCALING GROUP (Dual-AZ with Rolling Updates & ELB Health Checks)
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.project_name}-asg-"
  vpc_zone_identifier = aws_subnet.public[*].id

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  # Forward to ALB Target Group
  target_group_arns = [aws_lb_target_group.app.arn]

  # ELB Application-level Health Checks
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Production Zero-Downtime Rolling Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }
}
