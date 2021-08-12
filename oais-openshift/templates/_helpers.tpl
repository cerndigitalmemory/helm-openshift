{{/* Annotations to automatically roll deployments */}}
{{- define "oais.env-checksum" }}
checksum/env: {{ include (print $.Template.BasePath "/env.yaml") . | sha256sum }}
{{- end }}

{{- define "oais.config-checksum" }}
checksum/config: {{ include (print $.Template.BasePath "/config.yaml") . | sha256sum }}
{{- end }}