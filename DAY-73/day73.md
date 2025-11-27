
# Jenkins - Introduction and Installation, Environment Variables, and Build Triggers

Introduction to Jenkins, installation process, setting up environment variables, and configuring build triggers such as periodical scheduling, Poll SCM, and webhooks for continuous integration.

---

## Multi-Environment Build & Deployment Pipeline Using Jenkins Environment Variables

Here is a complex, real-time DevOps task that will deeply test your understanding of **Jenkins Environment Variables**, including **Local Variables**, **System Variables**, and **Jenkins Built-in Variables** — with scenarios, use cases, and fully working examples.

---

# 🎯 Objective

Create a Jenkins pipeline that:

1. Builds, tests, and deploys to Dev, Staging, and Production.
2. Uses:
   - **Local Variables** — variables defined inside pipeline/steps.
   - **System Variables** — variables coming from the OS (Java, PATH, HOME, environment).
   - **Jenkins Built-in Variables** — JOB_NAME, BUILD_NUMBER, WORKSPACE, etc.
3. Dynamically selects deployment scripts based on environment.
4. Stores logs using variable-driven file naming.
5. Produces different Docker image tags using combinations of variable types.
6. Sends a Slack notification using variable metadata.

---

# 🧩 Real-Time Scenario

## Company Requirement

Your company is deploying a Python microservice to 3 environments:

| Environment | Branch | Deployment Target       |
|------------|--------|--------------------------|
| Dev        | dev    | Minikube cluster         |
| Staging    | stage  | Dev EKS cluster          |
| Prod       | main   | Production EKS cluster   |

### Constraints

- Each environment must generate **unique image tags** using:  
  `BUILD_NUMBER`, `BRANCH_NAME`, system date.
- System path must be validated using **System Variables**.
- Deployment script uses **Local Variables**.
- Logs must be saved using **Jenkins variables**.

---

# ⚙️ Pipeline Requirements

## 1. Validate System Variables

Check if:

- JAVA_HOME is set  
- PATH contains docker  
- System date is captured (`date` command)

## 2. Use Local Variables

Within each stage, define:

- Deployment namespace  
- Deployment file path  
- Image tag  

## 3. Use Jenkins Built-in Variables

Examples:

- `$BUILD_NUMBER`  
- `$BUILD_ID`  
- `$BRANCH_NAME`  
- `$WORKSPACE`  
- `$JOB_NAME`  

## 4. Produce Logs Named As:

deploy-${JOB_NAME}-${BRANCH_NAME}-${BUILD_NUMBER}.log

## 5. Deployment Strategy

- If `BRANCH_NAME == "dev"` → deploy to Minikube  
- If `BRANCH_NAME == "stage"` → deploy to Dev EKS  
- If `BRANCH_NAME == "main"` → deploy to Production EKS  

---

# 🧨 Complex Jenkinsfile (Complete Working Example)

```groovy
pipeline {
    agent any

    environment {
        // Jenkins Built-in Variables Examples
        CI = "true"
        DOCKER_HUB = "your-dockerhub-user"

        // System Variables (injected from Node)
        JAVA_HOME = "${env.JAVA_HOME}"
        PATH = "${env.PATH}"
    }

    stages {

        stage('Validate System Vars') {
            steps {
                sh '''
                  echo "---- System Variables ----"
                  echo "JAVA_HOME = $JAVA_HOME"
                  echo "PATH = $PATH"

                  which docker || { echo "Docker not found in PATH!"; exit 1; }

                  SYSTEM_DATE=$(date +%Y%m%d-%H%M%S)
                  echo "System Date = $SYSTEM_DATE"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {

                    // ---- Local Variables ----
                    def systemDate = sh(script: "date +%Y%m%d-%H%M", returnStdout: true).trim()
                    def imageTag = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${systemDate}"

                    echo "Image Tag: ${imageTag}"

                    sh """
                        docker build -t ${DOCKER_HUB}/python-app:${imageTag} .
                        docker push ${DOCKER_HUB}/python-app:${imageTag}
                    """
                }
            }
        }

        stage('Deploy Based on Branch') {
            steps {
                script {

                    // ---- Local Variables ----
                    def targetNamespace = ""
                    def deployFile = ""

                    if (env.BRANCH_NAME == "dev") {
                        targetNamespace = "dev-namespace"
                        deployFile = "k8s/dev-deployment.yaml"

                    } else if (env.BRANCH_NAME == "stage") {
                        targetNamespace = "stage-namespace"
                        deployFile = "k8s/stage-deployment.yaml"

                    } else if (env.BRANCH_NAME == "main") {
                        targetNamespace = "prod-namespace"
                        deployFile = "k8s/prod-deployment.yaml"
                    }

                    echo "TARGET NAMESPACE = ${targetNamespace}"
                    echo "Using Deploy File = ${deployFile}"

                    // Deployment Log
                    def logFile = "deploy-${JOB_NAME}-${BRANCH_NAME}-${BUILD_NUMBER}.log"

                    sh """
                        echo "Deploying to ${targetNamespace}" | tee ${logFile}

                        kubectl apply -n ${targetNamespace} -f ${deployFile} | tee -a ${logFile}
                    """

                    archiveArtifacts artifacts: logFile
                }
            }
        }
    }

    post {
        success {
            echo "Deployment Completed Successfully!"

            // Example Slack Notification
            echo """
            Slack Notification:
            Job = ${JOB_NAME}
            Build = ${BUILD_NUMBER}
            Branch = ${BRANCH_NAME}
            Workspace = ${WORKSPACE}
            """
        }
    }
}


⸻

🧪 Breakdown of Variable Types with Examples

✔️ 1. Local Variables (inside script block)

Used only within the block.

def imageTag = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
def targetNamespace = "dev"

📌 Use Case

Dynamic decisions (deployment target, file paths)

⸻

✔️ 2. System Variables

In Jenkins → injected from the OS

Examples:
	•	env.PATH
	•	env.JAVA_HOME
	•	env.HOME
	•	env.USER
	•	env.SHELL

echo "JAVA_HOME = ${env.JAVA_HOME}"
echo "PATH = ${env.PATH}"

📌 Use Case

Ensure system environment is correctly configured.

⸻

✔️ 3. Jenkins Built-in Variables

These are available automatically.

Variable	Meaning
JOB_NAME	Name of the job
BUILD_NUMBER	Incremental build number
BRANCH_NAME	Git branch
WORKSPACE	Jenkins workspace path
BUILD_ID	Timestamp-based build ID
NODE_NAME	Jenkins node name
EXECUTOR_NUMBER	Executor slot

Example:

echo "Job: ${JOB_NAME}"
echo "Build: ${BUILD_NUMBER}"
echo "Workspace: ${WORKSPACE}"

📌 Use Case

Tagging, logging, notifications, artifact naming.


--------------------------

Nice — here’s a thorough, stage-by-stage walkthrough of the Jenkins pipeline you already have. I’ll explain what each stage does, why it’s there, the exact variables used, expected outputs, common failure causes, how to test it, and hardening / improvements you can apply.

Stage-by-stage explanation (step-by-step)

⸻

1. Validate System Vars

Purpose: ensure the Jenkins agent/node has the required system-level tools and environment before doing any build or deploy work. Catch missing dependencies early so the pipeline fails fast with a clear error.

Where it runs: on whatever Jenkins agent is assigned (the agent any in the Jenkinsfile).

Key checks / actions in the stage:
	•	Print system variables for debug:
	•	echo "JAVA_HOME = $JAVA_HOME"
	•	echo "PATH = $PATH"
	•	Verify docker exists: which docker || { echo "Docker not found in PATH!"; exit 1; }
	•	Capture system date for later use: SYSTEM_DATE=$(date +%Y%m%d-%H%M%S)

Variables involved:
	•	System variables: env.JAVA_HOME, env.PATH (exposed into JAVA_HOME and PATH in environment{}).
	•	Local shell variable: SYSTEM_DATE (used for logging or tagging).

Expected output:
	•	Printed JAVA_HOME and PATH values.
	•	which docker returns path to docker binary; if not, the stage exits with code 1 and pipeline fails.

Common failure points:
	•	Docker not installed on the agent.
	•	JAVA_HOME not set (only relevant if your build needs Java).
	•	PATH missing expected entries for other binaries you rely on (kubectl, aws, helm, etc.).

How to test locally:
	•	Run the same shell commands on the target agent node manually or via ssh.
	•	Create a minimal freestyle job running the same shell snippet to validate agent environment.

Hardening / improvements:
	•	Check versions: docker --version, kubectl version --client, java -version.
	•	Fail with a clear message suggesting remediation (e.g., link to onboarding doc or runbook).
	•	Make checks conditional on the branch or job parameters (e.g., skip docker check for pure unit tests).

⸻

2. Build Docker Image

Purpose: build the application Docker image and push it to a registry using a reproducible, variable-driven tag.

What happens: a script {} block:
	•	Create local variable systemDate via sh(script: "date +%Y%m%d-%H%M", returnStdout: true).trim().
	•	Compose imageTag = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${systemDate}".
	•	Run:
	•	docker build -t ${DOCKER_HUB}/python-app:${imageTag} .
	•	docker push ${DOCKER_HUB}/python-app:${imageTag}

Variables involved:
	•	Jenkins built-ins: env.BRANCH_NAME, env.BUILD_NUMBER.
	•	Pipeline environment var: DOCKER_HUB.
	•	Local Groovy var: systemDate, imageTag.

Expected output:
	•	Docker image built and tagged.
	•	Docker push completes successfully to registry (Docker Hub or private registry).

Common failure points:
	•	Authentication issues pushing to the registry (credentials not configured).
	•	Docker daemon not running, or agent not privileged to run Docker (e.g., inside container).
	•	Dockerfile errors causing build failure.
	•	Large images timing out or hitting storage quotas.

How to test:
	•	Manually run docker build and docker push on the agent using the same tag pattern.
	•	Use a temporary test registry (or a registry namespace/test repo) to verify pushes.
	•	Check using docker pull <image> from another machine.

Security / best practices:
	•	Use Jenkins Credentials Binding to inject Docker credentials (don’t hardcode DOCKER_HUB secret).
	•	Use withCredentials([usernamePassword(...)]) or Docker plugin credential binding.
	•	Prefer ephemeral build agents or BuildKit with cache to reduce host pollution.
	•	Scan the image for vulnerabilities after pushing (trivy/snyk).

Variants:
	•	Build on remote Docker daemon or use Kaniko for unprivileged builds inside Kubernetes.
	•	Use multistage builds and explicit cache layers to speed up rebuilds.

⸻

3. Deploy Based on Branch

Purpose: determine the target deployment environment and apply Kubernetes manifests accordingly. Save a deployment log and archive it as a build artifact.

What happens (script logic):
	•	Local Groovy vars: targetNamespace, deployFile.
	•	Branch-based selection:
	•	dev → dev-namespace, k8s/dev-deployment.yaml
	•	stage → stage-namespace, k8s/stage-deployment.yaml
	•	main → prod-namespace, k8s/prod-deployment.yaml
	•	Compose logFile = "deploy-${JOB_NAME}-${BRANCH_NAME}-${BUILD_NUMBER}.log"
	•	Run:
	•	echo "Deploying to ${targetNamespace}" | tee ${logFile}
	•	kubectl apply -n ${targetNamespace} -f ${deployFile} | tee -a ${logFile}
	•	Archive the log with archiveArtifacts artifacts: logFile

Variables involved:
	•	Jenkins built-ins: JOB_NAME, BRANCH_NAME, BUILD_NUMBER, WORKSPACE.
	•	Local Groovy variables: targetNamespace, deployFile, logFile.
	•	External runtime: kubectl and kubeconfig context (implicitly required).

Expected output:
	•	kubectl apply output appended to the deploy-...log.
	•	archiveArtifacts stores the log in the Jenkins build artifacts for later review.

Common failure points:
	•	kubectl not installed or not found in PATH.
	•	kubeconfig / cluster credentials not available on the agent (auth error).
	•	Wrong namespace or missing resources causing kubectl apply to error.
	•	Manifest file paths incorrect or missing.
	•	Insufficient RBAC permission to create/update resources.

How to test:
	•	Manually run kubectl apply with the chosen manifest on the intended cluster.
	•	Use kubectl --dry-run=client or --server-dry-run to test manifests without applying.
	•	Validate namespace existence before apply: kubectl get ns <targetNamespace>.

Security / best practices:
	•	Store kubeconfig or cluster credentials in Jenkins Credentials (e.g., kubeconfig file credential) and inject them in the pipeline (do not store in repo).
	•	Perform validation and kubectl diff (or kubeval) before applying to catch schema/validation issues.
	•	Prefer GitOps (ArgoCD/Flux) to make deployments auditable and avoid direct kubectl apply from CI.
	•	If deploying to prod, require approval step (input) or require pipeline parameter CONFIRM=true.

Observability:
	•	After kubectl apply, run kubectl rollout status deployment/<name> -n <ns> and capture the result.
	•	Save release metadata (image tag -> git commit -> build number) in a release registry.

Rollback plan:
	•	Add kubectl rollout undo step in case failure is detected, or use kubectl rollout history for manual rollback info.

⸻

4. post { success { ... } } (Post actions)

Purpose: notify and summarize after a successful build+deploy.

What happens:
	•	Print confirmation message.
	•	Echo a slack notification text block:
	•	Job, Build, Branch, Workspace
	•	(Optional) You’d typically call a Slack plugin step here like slackSend or a webhook HTTP POST with build metadata and link.

Variables involved:
	•	JOB_NAME, BUILD_NUMBER, BRANCH_NAME, WORKSPACE, potentially BUILD_URL.

Expected output:
	•	Log lines in Jenkins console and (if configured) a Slack message or other notification.

Common failure points:
	•	Notification plugin not configured or incorrect credentials.
	•	Sensitive data accidentally printed — avoid printing secrets.

How to improve:
	•	Use slackSend(channel: '#ci', message: "...", attachments: [...]) with a Jenkins Slack plugin.
	•	Provide actionable links in notifications: build URL, artifact links, Kubernetes dashboard link.
	•	Send different notifications on failure, unstable, and always blocks.

⸻

Extra: Variable scope and how they map
	•	Global/Environment (pipeline environment{}): available across stages as env.<NAME> or ${NAME} in shell steps. Good for registry names, feature flags.
	•	Jenkins Built-in (env.BUILD_NUMBER, env.JOB_NAME, etc): always available — use for labels, artifact names, image tags.
	•	Local Groovy vars (inside script {}): ephemeral and only available in that script block. Good for temp computations (imageTag, file paths).
	•	Local shell vars (inside sh ''' ... '''): only available inside that shell; if you want their value back in Groovy, return stdout via sh(returnStdout: true).

⸻

Tests you should run (CI test checklist)
	1.	Agent readiness test: a job that runs the exact Validate System Vars snippet on every agent you plan to use.
	2.	Build-only test: run the pipeline with a parameter SKIP_DEPLOY=true so you only build + push image; confirm the image exists in registry.
	3.	Dry-run deploy: set DRY_RUN=true and replace kubectl apply with kubectl apply --dry-run=client (or --server-dry-run) to validate manifests.
	4.	End-to-end: run full pipeline against dev branch and verify the app comes up in Minikube and the deploy-...log appears in Jenkins.
	5.	Rollback simulation: test kubectl rollout undo in a non-prod environment.

⸻

Troubleshooting quick guide
	•	docker not found → install Docker on agent or configure remote docker host / use Kaniko.
	•	permission denied pushing image → configure Docker credentials in Jenkins credentials store and bind them.
	•	kubectl: command not found → install kubectl on agent or run deploy on a node with the binary.
	•	Error from server (Forbidden) → check service account RBAC, kubeconfig credentials used by Jenkins.
	•	manifest not found → ensure k8s/<env>-deployment.yaml is present in workspace; check WORKSPACE path.

⸻

Security & Credentials (must-do items)
	•	Store Docker registry credentials and kubeconfigs in Jenkins Credentials plugin (not in repo).
	•	Use withCredentials(...) to inject secrets.
	•	Limit which jobs can deploy to production via folder/job permissions or required approvals.
	•	Avoid printing secrets in logs; redact them if necessary.
	•	Use ephemeral build agents where possible; avoid long-lived credentials on agents.

⸻

Useful enhancements / optional extensions
	•	Parameterize environment: add parameters { choice(name: 'TARGET', choices: 'dev\nstage\nmain') } to allow manual selection.
	•	Manual approval for prod: add input { message 'Approve production deploy?' }.
	•	Blue/Green or Canary: deploy to a canary subset first and run smoke tests before shifting traffic.
	•	GitOps approach: push image tags/manifest updates to a Git repo watched by Argo/Flux, instead of direct kubectl apply.
	•	Release metadata registry: add step to write a JSON release file with imageTag, gitCommit, buildNumber to S3 or DB.
	•	Image scanning: integrate Trivy/Snyk after build, fail if vulnerabilities exceed threshold.
	•	Better logging: centralize logs to ELK/CloudWatch instead of just archived artifacts.

⸻

Example: Slack notification payload (improved)

You can replace the echo in post with slackSend:

post {
  success {
    slackSend (channel: '#deploys', color: 'good',
      message: "*Deployment Succeeded*\nJob: ${JOB_NAME}\nBuild: ${BUILD_NUMBER}\nBranch: ${BRANCH_NAME}\nImage: ${DOCKER_HUB}/python-app:${env.BUILD_NUMBER}\n<${env.BUILD_URL}|Open Build>")
  }
  failure {
    slackSend (channel: '#deploys', color: 'danger',
      message: "*Deployment Failed*\nJob: ${JOB_NAME}\nBuild: ${BUILD_NUMBER}\nBranch: ${BRANCH_NAME}\n<${env.BUILD_URL}|Open Build>")
  }
}

(Requires Jenkins Slack plugin and credentials configured.)

⸻

Final quick checklist before running this pipeline on production
	•	Docker registry credentials in Jenkins credentials store and referenced correctly.
	•	kubeconfigs / cluster access keys configured and tested for each environment.
	•	kubectl, docker, and any other tools installed on the agent.
	•	Manifests exist at k8s/dev-deployment.yaml, etc., with correct image placeholder or patched to use your ${imageTag}.
	•	Logging and artifact archive validated.
	•	Notifications configured (Slack, email) for success/failure.
	•	Approval gates for production deployments.

-----------------------------------⸻

Great — here are three progressively advanced versions of the Jenkins Environment Variables task:

✅ Beginner Version – Simple, clear, easy to practice
✅ Intermediate Version – Realistic CI scenario
✅ Expert Version – Full DevOps production pipeline with branching logic, dynamic manifests, logging, notifications, etc.

Each version includes:
	•	Real-time scenario
	•	Jenkinsfile
	•	Explanation
	•	Learning objectives

⸻

✅ 1. BEGINNER VERSION – Introduction to Jenkins Environment Variables

🎯 Goal

Understand local variables, system variables, and Jenkins built-in variables in the simplest possible pipeline.

⸻

📘 Scenario

You want to print environment information and generate a simple tag using Jenkins variables.

⸻

🧪 Jenkinsfile (Beginner Level)

pipeline {
    agent any

    stages {

        stage('Show Variables') {
            steps {
                script {
                    // Local Variable
                    def localVar = "Hello from local variable!"

                    echo "Local Var: ${localVar}"

                    // System Variables
                    echo "System PATH: ${env.PATH}"
                    echo "System HOME: ${env.HOME}"

                    // Jenkins Variables
                    echo "Job Name: ${env.JOB_NAME}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                    echo "Workspace: ${env.WORKSPACE}"
                }
            }
        }
    }
}


⸻

🎓 Learning Objectives
	•	What env.VARIABLE means
	•	Difference between System vs Jenkins variables
	•	How to create local Groovy variables
	•	How Jenkins exposes information automatically

⸻

✔️ What you achieve

You correctly print:
	•	Local variable
	•	System variables
	•	Jenkins variables

⸻

⸻

✅ 2. INTERMEDIATE VERSION – Build + Test + Tag With Jenkins Variables

🎯 Goal

Learn how Jenkins variables are used in image tagging, file naming, and multi-stage pipelines.

⸻

📘 Scenario

You want to build a Docker image with a tag that includes:
	•	BRANCH_NAME
	•	BUILD_NUMBER
	•	A timestamp

Store build logs using Jenkins metadata.

⸻

🧪 Jenkinsfile (Intermediate Level)

pipeline {
    agent any

    stages {

        stage('Prepare') {
            steps {
                script {
                    // Local timestamp variable
                    def timestamp = sh(script: "date +%Y%m%d-%H%M", returnStdout: true).trim()
                    
                    // Jenkins built-in variables
                    echo "Branch: ${env.BRANCH_NAME}"
                    echo "Build Number: ${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def timestamp = sh(script: "date +%Y%m%d-%H%M", returnStdout: true).trim()

                    // Compose tag using variables
                    env.IMAGE_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${timestamp}"

                    echo "Building Image with Tag: ${env.IMAGE_TAG}"

                    sh """
                        docker build -t myrepo/app:${IMAGE_TAG} .
                        docker save myrepo/app:${IMAGE_TAG} > build-${JOB_NAME}-${BUILD_NUMBER}.tar
                    """
                }
            }
        }

        stage('Archive Build Output') {
            steps {
                archiveArtifacts artifacts: "build-${JOB_NAME}-${BUILD_NUMBER}.tar"
            }
        }
    }
}


⸻

🎓 Learning Objectives
	•	Create reusable environment variables (using env.IMAGE_TAG)
	•	Use Jenkins metadata to name files
	•	Build and save Docker image with dynamic tags
	•	Organize multi-stage pipelines

⸻

✔️ What you achieve
	•	Dynamic Docker tag generation
	•	Build artifact creation (versioned tar)
	•	Showcasing system + Jenkins variables

⸻

⸻

✅ 3. EXPERT VERSION – Multi-Environment Deployment With Flexible Logic

🎯 Goal

Build a real DevOps production pipeline with:
	•	Branch-based deployment (dev / stage / prod)
	•	Local, system, and Jenkins variables
	•	Kubernetes deployments
	•	Log archiving
	•	Notification block
	•	Dynamic image tags

This mirrors how large companies build automated CI/CD.

⸻

📘 Scenario

A Python microservice needs to be:
	•	Built into a Docker image
	•	Tagged using variable combinations
	•	Deployed to:
	•	Minikube (dev branch)
	•	Staging EKS (stage branch)
	•	Production EKS (main branch)
	•	Deployment logs stored with build metadata

⸻

🧪 Jenkinsfile (Expert Level)

pipeline {
    agent any

    environment {
        DOCKER_HUB = "your-dockerhub-user"
        JAVA_HOME = "${env.JAVA_HOME}"
        PATH = "${env.PATH}"
    }

    stages {

        stage('Validate System Vars') {
            steps {
                sh '''
                  echo "JAVA_HOME: $JAVA_HOME"
                  echo "PATH: $PATH"
                  which docker || { echo "Docker not installed"; exit 1; }
                '''
            }
        }

        stage('Build Image') {
            steps {
                script {
                    def stamp = sh(script: "date +%Y%m%d-%H%M", returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${stamp}"

                    echo "Tagging as ${IMAGE_TAG}"

                    sh """
                        docker build -t ${DOCKER_HUB}/python-app:${IMAGE_TAG} .
                        docker push ${DOCKER_HUB}/python-app:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    // Determine deployment settings
                    def namespace = ""
                    def deployFile = ""

                    if (env.BRANCH_NAME == 'dev') {
                        namespace = "dev-namespace"
                        deployFile = "k8s/dev.yaml"

                    } else if (env.BRANCH_NAME == 'stage') {
                        namespace = "stage-namespace"
                        deployFile = "k8s/stage.yaml"

                    } else if (env.BRANCH_NAME == 'main') {
                        namespace = "prod-namespace"
                        deployFile = "k8s/prod.yaml"
                    }

                    echo "Deploying to namespace: ${namespace}"

                    def log = "deploy-${JOB_NAME}-${BRANCH_NAME}-${BUILD_NUMBER}.log"

                    sh """
                        echo "Deploying using ${deployFile}" | tee ${log}
                        kubectl apply -n ${namespace} -f ${deployFile} | tee -a ${log}
                    """

                    archiveArtifacts artifacts: log
                }
            }
        }
    }

    post {
        success {
            echo "Deployment succeeded!"
            echo "Image Tag: ${env.IMAGE_TAG}"
        }
        failure {
            echo "Deployment failed!"
        }
    }
}


⸻

🎓 Learning Objectives (Expert Level)

You learn how to:

✔️ Use all 3 variable types together
	•	Local → in script {} blocks
	•	System → PATH, JAVA_HOME
	•	Jenkins built-in → JOB_NAME, BUILD_NUMBER, BRANCH_NAME

✔️ Build flexible pipelines
	•	Auto-select environment based on branch
	•	Reusable variables
	•	Deployment file selection logic

✔️ Generate production-grade logs
	•	Named using job + branch + build number
	•	Archived for auditing

✔️ Work with Kubernetes deployments
	•	Namespaces
	•	Manifests
	•	Deploy logs

✔️ Add observability and notifications

⸻

🎉 What changes as you go from Beginner → Intermediate → Expert?

Skill Level	What You Learn
Beginner	Printing variables, understanding scope
Intermediate	Using variables in image tags & file names
Expert	Full CI/CD pipeline w/ branching, logs, deploys, Kubernetes


⸻
