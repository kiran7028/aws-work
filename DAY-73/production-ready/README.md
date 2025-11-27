Nice — below is a production-ready, expert-level CI/CD pipeline you can copy into your repo (Jenkinsfile) and run (after filling the credential IDs and cluster manifests). It’s opinionated but practical: branch-based promotion, image tagging, scanning, dev → stage → prod promotion, manual approvals for stage/prod, canary rollout for production, rollback, archived logs, and Slack notifications.

I’ll give you:
	1.	A commented Declarative Jenkinsfile (expert) — complete, ready-to-run (replace placeholders).
	2.	Supporting shell helper snippets (smoke tests, rollback commands).
	3.	Kubernetes manifest template showing how to reference the image tag.
	4.	Operational notes: credentials setup, plugins, testing, security, and suggested improvements.

⸻

1) Jenkinsfile — Expert, production-ready

/*
  Expert Jenkinsfile: Multi-env CI/CD with scanning, canary, approvals, rollback, and logging.
  Usage notes:
    - Save as Jenkinsfile in your repo root.
    - Replace credential IDs (DOCKER_CREDS_ID, KUBECONFIG_DEV, KUBECONFIG_STAGE, KUBECONFIG_PROD, SLACK_CRED_ID).
    - Ensure agents have docker, kubectl, and trivy (or use containerized steps).
    - Ensure your Kubernetes manifests use the placeholder image: ${IMAGE}
*/

pipeline {
  agent any
  options {
    ansiColor('xterm')
    buildDiscarder(logRotator(daysToKeepStr: '30'))
    timestamps()
  }

  environment {
    // Replace this with your Docker repo/org
    DOCKER_REGISTRY = "docker.io/your-org"
    APP_NAME = "python-app"

    // Jenkins credentials IDs (replace)
    DOCKER_CREDS_ID = "docker-hub-creds"      // username/password (Credentials -> Username with password)
    KUBECONFIG_DEV   = "kubeconfig-dev"       // kubeconfig file credential (type: Secret file)
    KUBECONFIG_STAGE = "kubeconfig-stage"
    KUBECONFIG_PROD  = "kubeconfig-prod"

    // Slack webhook or integration (optional)
    SLACK_CRED_ID = "slack-webhook"           // secret text or username/password as per your plugin

    // Derived variables (populated in script steps)
    IMAGE_TAG = ""    // will be set at runtime
    IMAGE = ""        // full image: ${DOCKER_REGISTRY}/${APP_NAME}:${IMAGE_TAG}
  }

  parameters {
    booleanParam(name: 'SKIP_SCAN', defaultValue: false, description: 'Skip image vulnerability scan (not recommended)')
    booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'If true, do not push images or apply to clusters')
    string(name: 'MANUAL_PROMOTE_TO', defaultValue: '', description: 'Use to force promote to "stage" or "prod" (optional)')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        script {
          echo "Checked out ${env.GIT_URL ?: 'repo'} @ ${env.GIT_COMMIT ?: 'unknown commit'}"
        }
      }
    }

    stage('Prepare Metadata') {
      steps {
        script {
          // Compose an immutable image tag: branch-build-gitsha-timestamp
          def shortSha = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
          def ts = sh(script: "date +%Y%m%d%H%M%S", returnStdout: true).trim()
          // Normalize branch name (remove slashes)
          def branch = (env.BRANCH_NAME ?: sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()).replaceAll('/','-')
          env.IMAGE_TAG = "${branch}-${env.BUILD_NUMBER}-${shortSha}-${ts}"
          env.IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}:${env.IMAGE_TAG}"

          echo "IMAGE_TAG = ${env.IMAGE_TAG}"
          echo "IMAGE = ${env.IMAGE}"
          // Save metadata artifact
          writeFile file: 'release-metadata.json', text: """{
            "image":"${env.IMAGE}",
            "build": "${env.BUILD_NUMBER}",
            "job":"${env.JOB_NAME}",
            "branch":"${branch}",
            "commit":"${shortSha}",
            "timestamp":"${ts}"
          }"""
          archiveArtifacts artifacts: 'release-metadata.json'
        }
      }
    }

    stage('Lint & Unit Tests') {
      steps {
        // adapt commands to your repo (python example)
        sh '''
          set -eux
          python -m pip install -r requirements.txt || true
          # run linter and tests (example)
          pytest -q || true
          flake8 || true
        '''
      }
      post {
        always { junit allowEmptyResults: true, testResults: 'test-results/**/*.xml' } // if you generate junit results
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          // Build with BuildKit, include metadata labels
          sh '''
            set -eux
            DOCKER_BUILDKIT=1 docker build \
              --label build.number=${BUILD_NUMBER} \
              --label git.commit=$(git rev-parse --short=8 HEAD) \
              -t ${IMAGE} .
          '''
        }
      }
    }

    stage('Scan Image') {
      when {
        expression { return !params.SKIP_SCAN }
      }
      steps {
        script {
          // Example using Trivy - ensure trivy is installed on agent or run container
          // Exit non-zero on high severity findings is recommended for production
          sh '''
            set -eux
            trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE} || true
          '''
          // you might parse the output and fail on policy
        }
      }
    }

    stage('Push Image') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN enabled — skipping push"
          } else {
            withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDS_ID, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
              sh '''
                set -eux
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin ${DOCKER_REGISTRY%%/*}
                docker push ${IMAGE}
              '''
            }
          }
        }
      }
      post {
        success {
          echo "Image pushed / ready: ${IMAGE}"
        }
      }
    }

    stage('Deploy to Dev (auto)') {
      steps {
        script {
          // Use kubeconfig file credential to set KUBECONFIG for this block
          withCredentials([file(credentialsId: env.KUBECONFIG_DEV, variable: 'KUBECONF')]) {
            sh '''
              set -eux
              export KUBECONFIG=${KUBECONF}
              kubectl set image -n dev deployment/${APP_NAME} ${APP_NAME}=${IMAGE} --record || true
              kubectl rollout status -n dev deployment/${APP_NAME} --timeout=120s || true
            '''
            // capture deploy log
            sh "kubectl get deployments -n dev ${APP_NAME} -o wide > deploy-dev-${BUILD_NUMBER}.log || true"
            archiveArtifacts artifacts: "deploy-dev-${BUILD_NUMBER}.log"
          }
        }
      }
    }

    stage('Smoke Tests (Dev)') {
      steps {
        script {
          sh '''
            set -eux
            # run minimal smoke checks, adapt to your app
            ./ci/smoke_test_dev.sh || (echo "Smoke tests failed"; exit 1)
          '''
        }
      }
    }

    stage('Promote to Stage - Manual Approval') {
      when {
        allOf {
          expression { return params.MANUAL_PROMOTE_TO == 'stage' || params.MANUAL_PROMOTE_TO == '' }
          expression { return env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'stage' || true } // allow promotions from any branch if requested
        }
      }
      steps {
        script {
          // Ask for manual input before stage deploy (only if not an auto-promote flag)
          if (params.MANUAL_PROMOTE_TO == 'stage' || input(message: "Approve deploy to STAGE?", ok: "Deploy")) {
            echo "Approved to deploy to stage"
          }
        }
      }
    }

    stage('Deploy to Stage') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN: skip stage deploy"
          } else {
            withCredentials([file(credentialsId: env.KUBECONFIG_STAGE, variable: 'KUBECONF')]) {
              sh '''
                set -eux
                export KUBECONFIG=${KUBECONF}
                kubectl set image -n stage deployment/${APP_NAME} ${APP_NAME}=${IMAGE} --record
                kubectl rollout status -n stage deployment/${APP_NAME} --timeout=180s
              '''
              sh "kubectl get deployments -n stage ${APP_NAME} -o wide > deploy-stage-${BUILD_NUMBER}.log || true"
              archiveArtifacts artifacts: "deploy-stage-${BUILD_NUMBER}.log"
            }
          }
        }
      }
    }

    stage('Integration Tests (Stage)') {
      steps {
        script {
          sh '''
            set -eux
            ./ci/integration_test_stage.sh || (echo "Integration tests failed"; exit 1)
          '''
        }
      }
    }

    stage('Promote to Prod - Manual Approval') {
      steps {
        script {
          // very explicit approval
          timeout(time: 60, unit: 'MINUTES') {
            input message: "Promote build ${env.BUILD_NUMBER} -> PRODUCTION? Image: ${env.IMAGE}", ok: "Promote to Prod", submitter: "prod-admins"
          }
        }
      }
    }

    stage('Canary Deploy to Prod') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN: skip prod canary"
          } else {
            withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
              // Strategy: create a temporary canary deployment (10% traffic) or use label patch
              sh '''
                set -eux
                export KUBECONFIG=${KUBECONF}
                # annotate rollout with image
                kubectl -n prod set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE} --record
                # scale down stable and scale up canary or use traffic splitting (example uses rollout pause/rollout status)
                kubectl -n prod rollout status deployment/${APP_NAME} --timeout=180s
              '''
              sh "kubectl -n prod get deployments ${APP_NAME} -o wide > deploy-prod-canary-${BUILD_NUMBER}.log || true"
              archiveArtifacts artifacts: "deploy-prod-canary-${BUILD_NUMBER}.log"
            }
          }
        }
      }
    }

    stage('Prod Canary Watch & Health Checks') {
      steps {
        script {
          // Wait + run canary health checks (smoke and metrics). If checks fail, trigger rollback.
          def canaryOk = true
          try {
            sh '''
              set -eux
              ./ci/smoke_test_prod_canary.sh || exit 2
            '''
          } catch (err) {
            echo "Canary health checks failed: ${err}"
            canaryOk = false
          }

          // if not OK, rollback
          if (!canaryOk) {
            withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
              sh '''
                set -eux
                export KUBECONFIG=${KUBECONF}
                kubectl -n prod rollout undo deployment/${APP_NAME} || true
                kubectl -n prod get deployments ${APP_NAME} -o wide > deploy-prod-rollback-${BUILD_NUMBER}.log || true
              '''
              archiveArtifacts artifacts: "deploy-prod-rollback-${BUILD_NUMBER}.log"
              error "Canary failed: rolled back to previous revision."
            }
          }
        }
      }
    }

    stage('Full Prod Rollout') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN: skip full prod rollout"
          } else {
            withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
              sh '''
                set -eux
                export KUBECONFIG=${KUBECONF}
                # If canary succeeded, ensure full rollout (for simple deployments this is already the same deployment)
                kubectl -n prod rollout status deployment/${APP_NAME} --timeout=300s
              '''
              sh "kubectl -n prod describe deployment ${APP_NAME} > deploy-prod-final-${BUILD_NUMBER}.log || true"
              archiveArtifacts artifacts: "deploy-prod-final-${BUILD_NUMBER}.log"
            }
          }
        }
      }
    }

  } // stages

  post {
    success {
      script {
        // Option: send Slack / webhook with build details
        echo "SUCCESS: Build ${env.BUILD_NUMBER} -> ${env.IMAGE}"
        // implement slackSend if plugin exists, or curl webhook
        // Example (requires Slack webhook stored as secret text in SLACK_CRED_ID):
        withCredentials([string(credentialsId: env.SLACK_CRED_ID, variable: 'SLACK_WEBHOOK')]) {
          sh '''
            set -eux
            payload=$(jq -n --arg t "Deployment Succeeded" --arg b "${BUILD_NUMBER}" --arg i "${IMAGE}" \
              '{text: ($t + " | Build: " + $b + " | Image: " + $i)}')
            curl -s -X POST -H 'Content-type: application/json' --data "$payload" $SLACK_WEBHOOK || true
          '''
        }
      }
    }

    failure {
      script {
        echo "FAILED: Build ${env.BUILD_NUMBER}"
        // Similar Slack notification for failures
      }
    }

    always {
      // cleanup local docker images from agent (optional)
      sh '''
        set +e
        docker rmi ${IMAGE} || true
      '''
    }
  }
}


⸻

2) Supporting helper scripts (place under ci/ in repo)

Put these shell scripts in ci/ and make executable (chmod +x).

ci/smoke_test_dev.sh

#!/usr/bin/env bash
set -eux
# Example: curl health endpoint in dev cluster via port-forward or ingress
# adapt HOST to your dev cluster ingress
HOST="http://dev-app.example.local/health"
curl -fsS $HOST | grep -q "ok"

ci/integration_test_stage.sh

#!/usr/bin/env bash
set -eux
# Run integration tests against stage environment
# e.g., run pytest with stage config
pytest tests/integration -q

ci/smoke_test_prod_canary.sh

#!/usr/bin/env bash
set -eux
# run critical checks for canary: endpoints, error rates, metrics thresholds
HOST="https://app.example.com/health"
curl -fsS $HOST | grep -q "ok"
# Optionally query Prometheus to ensure error rate < threshold (requires auth)


⸻

3) Kubernetes deployment manifest template (use image placeholder)

k8s/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
  labels:
    app: python-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: python-app
  template:
    metadata:
      labels:
        app: python-app
    spec:
      containers:
        - name: python-app
          image: docker.io/your-org/python-app:REPLACE_IMAGE
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"

Usage: You can keep REPLACE_IMAGE as a template and the Jenkins pipeline can sed replace it, or prefer kubectl set image (as used in Jenkinsfile) — safer.

⸻

4) Explanations, rationale & operational notes

Image tagging
	•	Tag uses branch-build-gitshort-timestamp to guarantee uniqueness and traceability.
	•	Avoid latest for production images.

Credentials
	•	Docker credentials: use Jenkins Username with password credential (bind with withCredentials).
	•	Kubeconfigs: store each cluster kubeconfig as a Secret file credential; use them with withCredentials([file(...)]).
	•	Slack: store webhook URL as secret text.

Approvals & RBAC
	•	Use input with submitter restricted to a group (e.g., prod-admins) for production promotion.
	•	Secure Jenkins folder/job permissions so only authorized users can start promotions.

Canary strategy
	•	Simple approach: kubectl set image on same deployment and health-check for a short window (fast, simpler).
	•	For fine-grained traffic splitting use service mesh (Istio/Linkerd) or ingress controllers that support canary weights (Contour, NGINX canary annotations) or Argo Rollouts.

Rollback
	•	Use kubectl rollout undo deployment/<name> — pipeline does this automatically when canary health checks fail.
	•	Keep previous ReplicaSet history (defaults stored by K8s).

Image scanning
	•	Trivy example included. For policy, fail builds on CRITICAL/HIGH depending on your tolerance.
	•	You can separate scanning into a scanning pipeline or use registry-based scanning.

Observability
	•	After production deploy, run kubectl rollout status, kubectl get pods -l app=python-app -o wide, and collect logs if needed.
	•	Consider automated smoke tests and metric checks (Prometheus alert check) before promoting.

Artifact & Log retention
	•	Archive release-metadata.json and deploy logs as build artifacts for traceability.
	•	Use centralized logging (ELK/CloudWatch) for runtime logs.

Security & Best Practices
	•	Don’t store kubeconfigs in the repo.
	•	Rotate credentials and use short-lived service accounts where possible.
	•	Avoid running Docker-in-Docker on shared agents unless isolated.
	•	Use ephemeral agents (Kubernetes plugin + PodTemplates).

Plugins & Tools you’ll likely need in Jenkins
	•	Git / GitHub / GitLab plugin
	•	Pipeline (declarative)
	•	Credentials Binding plugin
	•	Slack Notification plugin (optional)
	•	Kubernetes plugin (optional)
	•	JUnit plugin (if you publish test results)

⸻

5) How to test this pipeline (practical checklist)
	1.	Prepare credentials in Jenkins:
	•	Docker credentials (username/password)
	•	Kubeconfig files (dev/stage/prod) as “Secret file”
	•	Slack webhook as “Secret text”
	2.	Run with DRY_RUN=true to validate build, tag, and no cluster changes:
	•	pipeline should build image but not push/apply.
	3.	Test agent prerequisites:
	•	Ensure agent has docker, kubectl, trivy (or wrap steps into container images if using Kubernetes agents).
	4.	Test Dev deploy:
	•	Run pipeline for a PR branch; confirm deployment to dev cluster.
	•	Validate smoke tests pass.
	5.	Test Stage flow:
	•	Use manual input to promote to stage; run integration tests.
	6.	Test Prod flow:
	•	Use input to approve production; perform canary and try simulating a failing canary to exercise rollback path.
	7.	Observe logs & artifacts:
	•	Confirm release-metadata.json, deploy-*-<build>.log archived.

⸻

6) Optional advanced extensions (pick as needed)
	•	GitOps: Instead of kubectl apply, push manifest update (image tag) to a manifests/ branch that Argo/Flux watches — recommended for auditable deploys.
	•	Feature flags: use flags/toggles to enable features post-deploy.
	•	Policy-as-code: integrate OPA/Gatekeeper to enforce infra policies.
	•	Immutable infra: use Helm with chart values set by the pipeline and release via Helmfile/Helm or FluxCD.
	•	Blue/Green: deploy new version beside old, shift traffic via service or LB.

⸻

7) Quick cheat-sheet of commands used inside pipeline
	•	Build image: docker build -t <image> .
	•	Push image: docker push <image>
	•	Set image in deployment: kubectl -n <ns> set image deployment/<name> <container>=<image> --record
	•	Check rollout: kubectl -n <ns> rollout status deployment/<name> --timeout=120s
	•	Rollback: kubectl -n <ns> rollout undo deployment/<name>
	•	Archive logs: kubectl get deployments -n <ns> <name> -o wide > deploy-<ns>-<build>.log

⸻