Here is the Markdown (.md) formatted version of the entire explanation — clean, structured, and ready to use.

⸻

🌱 Introduction to Terraform, Installation, and AWS Provider Setup

📘 What is Terraform? (Simple Explanation)

Terraform is a tool that helps you create, manage, and delete cloud resources using code instead of clicking in the AWS console.

Think of Terraform like a remote control for your cloud infrastructure.

This approach is called Infrastructure as Code (IaC).

⸻

📝 Why Use Terraform?

Without Terraform	With Terraform
Manually create EC2, S3, etc.	Write code → Terraform builds everything
Hard to track changes	Version controlled in Git
Prone to human mistakes	Repeatable, predictable
Hard to replicate environments	Easily create Dev/QA/Prod


⸻

🛠️ Install Terraform

1. Download Terraform

Go to: https://developer.hashicorp.com/terraform/downloads
Choose your OS (Windows, Linux, macOS).

⸻

2. Install (Example: macOS using Homebrew)

brew tap hashicorp/tap
brew install hashicorp/tap/terraform


⸻

3. Verify Installation

terraform -version


⸻

☁️ Setting Up AWS Provider

Terraform needs permission to talk to AWS.
To do this, you configure AWS CLI credentials.

⸻

✔ Step 1: Install AWS CLI

Guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

Check:

aws --version


⸻

✔ Step 2: Configure AWS Credentials

aws configure

Fill in:

AWS Access Key ID: <your access key>
AWS Secret Access Key: <your secret key>
Default region name: ap-south-1
Default output format: json


⸻

✔ Step 3: Create Terraform Project Folder

mkdir terraform-demo
cd terraform-demo


⸻

✔ Step 4: Create main.tf File

# Tell Terraform to use AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS provider
provider "aws" {
  region = "ap-south-1"
}


⸻

✔ Step 5: Initialize Terraform

terraform init

Terraform downloads the AWS provider plugin.

⸻

🚀 Example: Create an EC2 Instance

Add this to main.tf:

resource "aws_instance" "demo" {
  ami           = "ami-0e53db6fd757e38c7"
  instance_type = "t2.micro"
}

Deploy it:

terraform apply

Type yes → EC2 instance is created.

⸻

✅ Summary (Easy Words)
	•	Terraform = tool to build cloud resources using code
	•	Install Terraform → install AWS CLI → configure credentials
	•	Create main.tf with AWS provider
	•	Run terraform init
	•	Now you can deploy AWS resources

⸻
