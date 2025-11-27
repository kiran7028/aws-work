{{- define "python-app.fullname" -}}
{{ include "python-app.name" . }}-{{ .Release.Name }}
{{- end }}

{{- define "python-app.name" -}}
{{ .Chart.Name }}
{{- end }}