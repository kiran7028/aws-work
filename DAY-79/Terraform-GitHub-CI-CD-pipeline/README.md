📌 How This CI/CD Pipeline Works (Simple Words)

When you create a Pull Request:
	•	GitHub Action runs
	•	Checks formatting
	•	Validates Terraform syntax
	•	Runs Terraform Plan
	•	Shows any changes

When code is merged to main:
	•	GitHub Action runs
	•	Terraform Apply executes
	•	AWS resources are created/updated/deleted

⸻

🧪 Local Workflow (Before Pushing Code)
	1.	terraform fmt
	2.	terraform init
	3.	terraform validate
	4.	terraform plan
	5.	Commit & push

⸻

🛡️ Security Best Practices

✔ Never store AWS keys in .tf files
✔ Always use GitHub Secrets
✔ Protect main branch
✔ Review Terraform plans before applying
✔ Use S3 backend for state