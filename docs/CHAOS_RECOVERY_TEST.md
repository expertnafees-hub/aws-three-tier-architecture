# Controlled Single-Instance Failure & Self-Healing Test

> **Target architecture:** AWS multi-AZ three-tier portfolio project  
> **Components under test:** Application Load Balancer, Target Group health checks, Auto Scaling Group  
> **Failure mode:** Intentional termination of one EC2 application instance

## Purpose

This runbook tests one specific failure scenario: loss of a single application instance while another healthy target remains available in a second Availability Zone.

It is **not** proof of universal zero downtime, regional disaster recovery, or complete production resilience. Record and report only what you actually observe during the test.

## Expected behavior

1. Requests are sent continuously through the application entrypoint.
2. One EC2 application instance is intentionally terminated.
3. The ALB stops routing new traffic to the failed/unhealthy target after health state changes.
4. Remaining healthy targets continue serving requests if sufficient healthy capacity exists.
5. The Auto Scaling Group detects the capacity deficit and launches replacement capacity.
6. The replacement instance runs user data, passes target-group health checks, and returns to service.

## Test prerequisites

- The stack is deployed successfully.
- The Auto Scaling Group has at least two healthy instances across multiple Availability Zones.
- The target group reports all intended targets as healthy.
- You are authenticated to the correct AWS account and region.
- You understand that terminating an instance is a destructive action.

Before running the test:

```bash
aws sts get-caller-identity
aws configure get region
terraform output
```

## Step 1: Start the repository probe

The probe uses `application_url`, so it follows the configured entrypoint: ALB HTTP for the default lab or the custom HTTPS domain when enabled.

```bash
./scripts/chaos_test.sh | tee chaos-test-$(date +%Y%m%d-%H%M%S).log
```

Keep the resulting log as evidence if you plan to discuss the test in a portfolio or interview.

## Step 2: Confirm target health

Use the exact target-group ARN from Terraform rather than guessing a resource name:

```bash
TG_ARN=$(terraform output -raw target_group_arn)

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table
```

Do not continue unless the expected application targets are healthy.

## Step 3: Identify the Auto Scaling Group and instances

Use the exact ASG name from Terraform:

```bash
ASG_NAME=$(terraform output -raw autoscaling_group_name)

echo "ASG=$ASG_NAME"

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,AvailabilityZone,HealthStatus,LifecycleState]' \
  --output table
```

## Step 4: Terminate exactly one application instance

Select one current instance deliberately and verify it before termination.

```bash
TARGET_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "About to terminate: $TARGET_ID"
aws ec2 describe-instances \
  --instance-ids "$TARGET_ID" \
  --query 'Reservations[0].Instances[0].[InstanceId,Placement.AvailabilityZone,State.Name]' \
  --output table
```

Then terminate it:

```bash
aws ec2 terminate-instances --instance-ids "$TARGET_ID"
```

## Step 5: Observe the test

Keep the HTTP probe running and separately watch Auto Scaling activity:

```bash
watch -n 5 "aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name '$ASG_NAME' \
  --max-items 5 \
  --query 'Activities[*].[StartTime,StatusCode,Description]' \
  --output table"
```

Also watch target health:

```bash
watch -n 5 "aws elbv2 describe-target-health \
  --target-group-arn '$TG_ARN' \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table"
```

## What to record

Capture actual values instead of writing expected results as facts:

- test start time
- terminated instance ID and Availability Zone
- number of HTTP requests sent
- number of failed/non-200 requests observed
- time until the failed target stopped receiving traffic
- time until replacement capacity launched
- time until the replacement target became healthy
- any 5xx/timeout behavior

## How to describe the result accurately

Good:

> During a controlled single-instance termination test, I sent one HTTP request per second through the application entrypoint. In that specific run, I observed 0 failed requests while the remaining healthy target served traffic. The Auto Scaling Group launched replacement capacity, which became healthy after X seconds.

Bad:

> My architecture guarantees zero downtime.

One successful test demonstrates behavior under that tested condition. It does not prove every failure mode, every traffic level, or every dependency failure.

## Additional failure tests worth running

After the single-instance test, expand carefully:

- break the target-group health-check path
- stop Nginx without terminating the instance
- test loss of one NAT Gateway/AZ
- enable RDS Multi-AZ and test a controlled database failover
- test an application deployment with an unhealthy build
- verify CloudWatch alarms and SNS delivery

Run only tests whose blast radius and cost you understand.

## Cleanup

Confirm the Auto Scaling Group returns to desired capacity and all intended targets become healthy:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances[*].[InstanceId,HealthStatus,LifecycleState]]' \
  --output table
```

If this is a temporary lab, destroy it after collecting evidence to avoid ongoing charges.
