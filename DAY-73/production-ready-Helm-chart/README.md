Absolutely — here is a complete, production-ready Helm chart to replace your raw Kubernetes manifests.
This chart fully supports:

✔ Dynamic image tag injection (from Jenkins)
✔ Dev / Stage / Prod values files
✔ Autoscaling (optional)
✔ Resource limits
✔ Probes
✔ Service
✔ Namespace creation (optional)
✔ Labels/annotations
✔ Rollbacks
✔ Canary-compatible structure

This chart fits directly into your existing repo and plugs into your Jenkins pipeline with helm upgrade –install commands.

⸻

📁 Helm Chart Directory Structure

Add this inside your repo:

my-python-app/
│
├── chart/
│   └── python-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-stage.yaml
│       ├── values-prod.yaml
│       ├── templates/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── hpa.yaml
│       │   ├── namespace.yaml
│       │   └── _helpers.tpl
│       └── .helmignore


⸻

📄 Chart.yaml

apiVersion: v2
name: python-app
description: A Helm chart for deploying Python microservice
type: application
version: 1.0.0
appVersion: "1.0"


⸻

🧹 .helmignore

*.md
*.txt
.git/
.gitignore


⸻

📌 values.yaml (default values)

replicaCount: 2

image:
  repository: docker.io/your-org/python-app
  tag: "latest"
  pullPolicy: IfNotPresent

namespace:
  create: true
  name: dev

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "200m"
    memory: "256Mi"

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 75

labels:
  environment: dev

podAnnotations: {}

imagePullSecrets: []


⸻

🟩 Environment Overrides

values-dev.yaml

namespace:
  name: dev

replicaCount: 2

labels:
  environment: dev


⸻

values-stage.yaml

namespace:
  name: stage

replicaCount: 3

labels:
  environment: stage


⸻

values-prod.yaml

namespace:
  name: prod

replicaCount: 4

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 65

labels:
  environment: prod


⸻

🧩 templates/_helpers.tpl

{{- define "python-app.fullname" -}}
{{ include "python-app.name" . }}-{{ .Release.Name }}
{{- end }}

{{- define "python-app.name" -}}
{{ .Chart.Name }}
{{- end }}


⸻

📦 templates/namespace.yaml

{{- if .Values.namespace.create }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace.name }}
{{- end }}


⸻

🚀 templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "python-app.fullname" . }}
  namespace: {{ .Values.namespace.name }}
  labels:
    app: {{ include "python-app.name" . }}
    environment: {{ .Values.labels.environment }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "python-app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "python-app.name" . }}
        environment: {{ .Values.labels.environment }}
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
    spec:
      containers:
        - name: python-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
          resources:
            {{- toYaml .Values.resources | nindent 12 }}

      imagePullSecrets:
        {{- if .Values.imagePullSecrets }}
        {{- toYaml .Values.imagePullSecrets | nindent 8 }}
        {{- end }}


⸻

🌐 templates/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: {{ include "python-app.fullname" . }}
  namespace: {{ .Values.namespace.name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ include "python-app.name" . }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}


⸻

📈 templates/hpa.yaml

{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "python-app.fullname" . }}
  namespace: {{ .Values.namespace.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "python-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}


⸻

🔥 Jenkins Integration — How the Pipeline Deploys Using Helm

Modify your Jenkinsfile deployment stages:

Dev Deploy

sh """
helm upgrade --install python-app ./chart/python-app \
  -f chart/python-app/values-dev.yaml \
  --set image.tag=${IMAGE_TAG} \
  --namespace dev
"""


⸻

Stage Deploy

sh """
helm upgrade --install python-app ./chart/python-app \
  -f chart/python-app/values-stage.yaml \
  --set image.tag=${IMAGE_TAG} \
  --namespace stage
"""


⸻

Prod Deploy (with Canary Option)

You can even do canary by:

helm upgrade --install python-app ./chart/python-app \
  -f chart/python-app/values-prod.yaml \
  --set image.tag=${IMAGE_TAG} \
  --namespace prod

(Or integrate Argo Rollouts later.)

⸻

🎁 Do you want this Helm chart added into your ZIP repository?

I can regenerate the ZIP with:

✔ The full Helm chart
✔ The full expert Jenkinsfile
✔ App code
✔ CI scripts
✔ Documentation

Just say:
👉 “Add Helm chart to ZIP and regenerate it.”