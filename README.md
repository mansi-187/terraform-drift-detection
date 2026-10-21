# Terraform Drift Detection & Auto-Remediation

Detects and automatically fixes AWS infrastructure drift. Terraform deploys a VPC, an Application Load Balancer, an Auto Scaling Group, and an S3 bucket. A scheduled GitHub Actions workflow then compares the real infrastructure against the code and reverts any manual changes.

**Key features:** scheduled drift checks, auto-remediation, GitHub issue tracking, optional Slack notifications, remote state with locking.

---

## What is drift?

Drift happens when real infrastructure no longer matches what Terraform says it should be. A typical cause is someone changing a resource by hand in the AWS console, for example opening SSH to the internet on a security group. This project finds that kind of change and reverts it automatically.

## How it works

```
GitHub Actions (every ~5 min)
        |
        v
terraform init  -->  terraform plan -detailed-exitcode
                              |
          +-------------------+-------------------+
          |                   |                   |
      exit 0              exit 2              exit 1
   (no changes)       (drift found)            (error)
          |                   |                   |
  close open drift      terraform apply     fail the run
      issue            open GitHub issue
                       (Slack alert, if set)
```

1. GitHub Actions runs on a schedule (and on demand).
2. `terraform plan -detailed-exitcode` compares actual state to the desired state.
3. Exit code `2` means drift. The workflow runs `terraform apply` to put things back.
4. It opens a GitHub issue labeled `drift`, and sends a Slack message if a webhook is configured.
5. On the next clean run (exit code `0`), the issue is closed automatically.

| Exit code | Meaning | Workflow action |
|---|---|---|
| 0 | No changes | Close any open drift issue |
| 1 | Error | Fail the run |
| 2 | Drift detected | Apply, open issue, notify |

## Architecture

- **VPC** with two public subnets across two availability zones, an internet gateway, and a public route table
- **Security groups** for the ALB (HTTP from anywhere) and the instances (HTTP from the ALB only)
- **Application Load Balancer** with a target group and an HTTP listener
- **Auto Scaling Group** with a launch template running Apache on Amazon Linux 2023
- **S3 bucket** with versioning and a public access block
- **Remote state** in a versioned, encrypted S3 bucket with state locking

Public subnets only are used to avoid NAT gateway costs (roughly $32/month each).

## Project structure

```
terraform-drift-detection/
├── .github/workflows/drift_detection.yml   # scheduled drift check
├── scripts/
│   ├── setup-backend.sh                    # creates the state bucket and lock table
│   └── user_data.sh                        # instance bootstrap script
├── main.tf              # provider, data sources
├── vpc.tf               # VPC, subnets, routing
├── security_groups.tf   # ALB and instance security groups
├── alb.tf               # load balancer, target group, listener
├── asg.tf               # launch template and Auto Scaling Group
├── s3.tf                # application S3 bucket
├── variables.tf         # input variables
├── outputs.tf           # ALB DNS name, VPC ID, bucket name
├── backend.tf           # S3 backend declaration
├── backend-dev.hcl      # dev backend settings
└── dev.tfvars           # dev variable values
```
