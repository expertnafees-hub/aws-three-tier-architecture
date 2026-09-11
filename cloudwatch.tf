# -----------------------------------------------------------------------------
# CLOUDWATCH ALARMS & OBSERVABILITY TELEMETRY
# -----------------------------------------------------------------------------
# Provides comprehensive enterprise monitoring for Tier 1 (ALB), Tier 2 (ASG/EC2),
# and Tier 3 backend components with automated SNS alerting.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 1. SNS TOPIC FOR DEVOPS ALERTS
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-devops-alerts"

  tags = {
    Name        = "${var.project_name}-devops-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# 2. ALB 5XX TARGET SERVER ERROR ALARM (Tier 1 Gateway)
# -----------------------------------------------------------------------------
# Triggers immediately if backend application instances produce HTTP 5XX responses.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggers when ALB target instances return HTTP 5XX server errors."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-5xx-alarm"
  }
}

# -----------------------------------------------------------------------------
# 3. ALB TARGET RESPONSE LATENCY ALARM (p95 SLA Protection)
# -----------------------------------------------------------------------------
# Triggers if p95 backend response time breaches 1.0 second over two 60s windows.
resource "aws_cloudwatch_metric_alarm" "alb_high_latency" {
  alarm_name          = "${var.project_name}-alb-high-target-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 1.0
  alarm_description   = "Triggers when ALB p95 target response time exceeds 1000ms."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-latency-alarm"
  }
}

# -----------------------------------------------------------------------------
# 4. UNHEALTHY HOSTS COUNT ALARM (Target Group Degraded State)
# -----------------------------------------------------------------------------
# Triggers if any EC2 instance fails ALB health check probes.
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-tg-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers when 1 or more backend targets fail ALB health checks."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-unhealthy-hosts-alarm"
  }
}

# -----------------------------------------------------------------------------
# 5. EC2 AUTO SCALING GROUP HIGH CPU UTILIZATION ALARM (Tier 2 Compute)
# -----------------------------------------------------------------------------
# Triggers if ASG fleet average CPU utilization exceeds 80% for 4 minutes.
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "${var.project_name}-asg-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when Auto Scaling Group average CPU utilization reaches or exceeds 80%."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = {
    Name = "${var.project_name}-asg-cpu-alarm"
  }
}

# -----------------------------------------------------------------------------
# 6. ENTERPRISE DEVOPS OBSERVABILITY DASHBOARD
# -----------------------------------------------------------------------------
# Real-time operational telemetry across network ingress, latency, health, and compute.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-telemetry"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Tier 1: ALB Traffic & HTTP Errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { color = "#22D3EE", label = "Total Requests" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { color = "#FF0000", label = "Target 5XX Errors" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { color = "#FF9900", label = "Target 4XX Errors" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { color = "#D63384", label = "ALB 5XX Errors" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Tier 1: Target Response Latency (p95 & Average)"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "p95", color = "#FF9900", label = "p95 Latency (s)" }],
            ["...", { stat = "Average", color = "#22D3EE", label = "Average Latency (s)" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Tier 2: Target Group Fleet Health"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { color = "#3FB950", label = "Healthy Hosts" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { color = "#FF0000", label = "Unhealthy Hosts" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Tier 2: EC2 Auto Scaling Group CPU Utilization (%)"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name, { color = "#FF9900", label = "ASG Avg CPU %" }]
          ]
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      }
    ]
  })
}
