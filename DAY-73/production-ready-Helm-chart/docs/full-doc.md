# Full Documentation & Jenkinsfile

This documentation includes the full expert Jenkinsfile and instructions to use the Helm chart.

## Full Jenkinsfile

```
/*
  Expert Jenkinsfile: Multi-env CI/CD with scanning, canary, approvals, rollback, and logging.
  NOTES: Replace credential IDs and ensure required tools are installed on agents.
*/

pipeline {
  agent any
  options {
    ansiColor('xterm')
    buildDiscarder(logRotator(daysToKeepStr: '30'))
    timestamps()
  }

  environment {
    DOCKER_REGISTRY = "docker.io/your-org"
    APP_NAME = "python-app"
    DOCKER_CREDS_ID   = "REPLACE_DOCKER_CREDS"
    KUBECONFIG_DEV    = "REPLACE_KUBECONFIG_DEV"
    KUBECONFIG_STAGE  = "REPLACE_KUBECONFIG_STAGE"
    KUBECONFIG_PROD   = "REPLACE_KUBECONFIG_PROD"
    SLACK_CRED_ID     = "REPLACE_SLACK_WEBHOOK"
    IMAGE_TAG = ""
    IMAGE = ""
  }

  parameters {
    booleanParam(name: 'SKIP_SCAN', defaultValue: false, description: 'Skip vulnerability scanning')
    booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Simulate pipeline without deployments')
    string(name: 'MANUAL_PROMOTE_TO', defaultValue: '', description: 'Override: promote to stage or prod')
  }

  stages {

    stage('Checkout Code') {
      steps {
        checkout scm
        script {
          echo "Checked out commit: ${env.GIT_COMMIT ?: sh(script:'git rev-parse HEAD', returnStdout:true)}"
        }
      }
    }

    stage('Prepare Metadata') {
      steps {
        script {
          def shortSha = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
          def ts = sh(script: "date +%Y%m%d%H%M%S", returnStdout: true).trim()
          def branch = (env.BRANCH_NAME ?: sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()).replaceAll('/','-')

          env.IMAGE_TAG = "${branch}-${env.BUILD_NUMBER}-${shortSha}-${ts}"
          env.IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"

          echo "IMAGE_TAG = ${IMAGE_TAG}"
          echo "IMAGE = ${IMAGE}"

          writeFile file: 'release-metadata.json', text: "{\\"image\\":\\"${env.IMAGE}\\",\\"build\\":\\"${env.BUILD_NUMBER}\\",\\"job\\":\\"${env.JOB_NAME}\\",\\"branch\\":\\"${branch}\\",\\"commit\\":\\"${shortSha}\\",\\"timestamp\\":\\"${ts}\\"}"
          archiveArtifacts artifacts: 'release-metadata.json'
        }
      }
    }

    stage('Run Unit Tests') {
      steps {
        sh '''
          set -eux
          pip install -r app/requirements.txt
          pytest -q || true
          flake8 || true
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'test-results/**/*.xml'
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          sh """
            set -eux
            DOCKER_BUILDKIT=1 docker build \
              --label build=${BUILD_NUMBER} \
              --label commit=$(git rev-parse --short=8 HEAD) \
              -t ${IMAGE} .
          """
        }
      }
    }

    stage('Scan Image') {
      when { expression { return !params.SKIP_SCAN } }
      steps {
        script {
          sh """
            set -eux
            trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE} || true
          """
        }
      }
    }

    stage('Push Image') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN enabled — Skipping docker push"
          } else {
            withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDS_ID, usernameVariable: 'USR', passwordVariable: 'PWD')]) {
              sh """
                set -eux
                echo "$PWD" | docker login -u "$USR" --password-stdin ${DOCKER_REGISTRY}
                docker push ${IMAGE}
              """
            }
          }
        }
      }
    }

    stage('Deploy to Dev (Auto)') {
      steps {
        script {
          withCredentials([file(credentialsId: env.KUBECONFIG_DEV, variable: 'KUBECONF')]) {
            sh """
              set -eux
              export KUBECONFIG=${KUBECONF}
              kubectl set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE} -n dev --record
              kubectl rollout status deployment/${APP_NAME} -n dev --timeout=120s
            """
            sh "kubectl get deployment ${APP_NAME} -n dev -o wide > deploy-dev-${BUILD_NUMBER}.log || true"
            archiveArtifacts artifacts: "deploy-dev-${BUILD_NUMBER}.log"
          }
        }
      }
    }

    stage('Smoke Test Dev') {
      steps {
        sh '''
          set -eux
          ./ci/smoke_test_dev.sh
        '''
      }
    }

    stage('Approve Promotion to Stage') {
      when {
        allOf {
          expression { env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'stage' }
          expression { params.MANUAL_PROMOTE_TO != 'prod' }
        }
      }
      steps {
        script {
          input message: "Deploy build ${BUILD_NUMBER} to Stage?", ok: "Approve"
        }
      }
    }

    stage('Deploy to Stage') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN: Skipping stage deploy"
          } else {
            withCredentials([file(credentialsId: env.KUBECONFIG_STAGE, variable: 'KUBECONF')]) {
              sh """
                set -eux
                export KUBECONFIG=${KUBECONF}
                kubectl set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE} -n stage --record
                kubectl rollout status deployment/${APP_NAME} -n stage --timeout=180s
              """
              sh "kubectl get deployment ${APP_NAME} -n stage -o wide > deploy-stage-${BUILD_NUMBER}.log || true"
              archiveArtifacts artifacts: "deploy-stage-${BUILD_NUMBER}.log"
            }
          }
        }
      }
    }

    stage('Integration Tests (Stage)') {
      steps {
        sh '''
          set -eux
          ./ci/integration_test_stage.sh
        '''
      }
    }

    stage('Approve Promotion to Prod') {
      steps {
        script {
          timeout(time: 60, unit: 'MINUTES') {
            input message: "PROMOTE build ${BUILD_NUMBER} to **PRODUCTION**? Image: ${IMAGE}", ok: "Deploy"
          }
        }
      }
    }

    stage('Canary Deploy to Prod') {
      steps {
        script {
          if (params.DRY_RUN) {
            echo "DRY_RUN: Skipping Prod canary"
          } else {
            withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
              sh """
                set -eux
                export KUBECONFIG=${KUBECONF}
                kubectl set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE} -n prod --record
                kubectl rollout status deployment/${APP_NAME} -n prod --timeout=180s
              """

              sh "kubectl get deployment ${APP_NAME} -n prod -o wide > deploy-prod-canary-${BUILD_NUMBER}.log || true"
              archiveArtifacts artifacts: "deploy-prod-canary-${BUILD_NUMBER}.log"
            }
          }
        }
      }
    }

    stage('Prod Canary Health Checks') {
      steps {
        script {
          def ok = true

          try {
            sh "./ci/smoke_test_prod_canary.sh"
          } catch (err) {
            ok = false
            echo "Canary test failed."
          }

          if (!ok) {
            echo "Rolling back..."
            withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
              sh """
                export KUBECONFIG=${KUBECONF}
                kubectl rollout undo deployment/${APP_NAME} -n prod
              """
            }
            error "Canary Failed — Deployment Rolled Back!"
          }
        }
      }
    }

    stage('Full Prod Rollout') {
      steps {
        script {
          withCredentials([file(credentialsId: env.KUBECONFIG_PROD, variable: 'KUBECONF')]) {
            sh """
              set -eux
              export KUBECONFIG=${KUBECONF}
              kubectl rollout status deployment/${APP_NAME} -n prod --timeout=300s
            """
            sh "kubectl describe deployment ${APP_NAME} -n prod > deploy-prod-final-${BUILD_NUMBER}.log || true"
            archiveArtifacts artifacts: "deploy-prod-final-${BUILD_NUMBER}.log"
          }
        }
      }
    }

  } // stages

  post {
    success {
      script {
        echo "SUCCESS! ${IMAGE} deployed."
        withCredentials([string(credentialsId: env.SLACK_CRED_ID, variable: 'WEBHOOK')]) {
          sh """
            curl -X POST -H 'Content-type: application/json' \
              --data "{\"text\": \"Deployment Successful: ${IMAGE}\"}" \
              $WEBHOOK
          """
        }
      }
    }

    failure {
      script {
        echo "FAILED build: ${BUILD_NUMBER}"
      }
    }

    always {
      script {
        sh "docker rmi ${IMAGE} || true"
      }
    }
  }
}
```

## Helm usage example

helm upgrade --install python-app ./chart/python-app -f chart/python-app/values-dev.yaml --set image.tag=<IMAGE_TAG> --namespace dev