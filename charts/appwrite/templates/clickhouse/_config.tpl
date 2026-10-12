{{- define "appwrite.clickhouse.config" -}}
system-log-ttl.xml: |
  {{- .Files.Get "files/clickhouse/system-log-ttl.xml" | nindent 2 }}
logging.xml: |
  {{- .Files.Get "files/clickhouse/logging.xml" | nindent 2 }}
{{- if .Values.clickhouse.builtin.metrics.enabled }}
prometheus.xml: |
  {{- .Files.Get "files/clickhouse/prometheus.xml" | nindent 2 }}
{{- end }}
users.xml: |
  {{- .Files.Get "files/clickhouse/users.xml" | replace "{{USERNAME}}" .Values.clickhouse.username | nindent 2 }}
{{- end }}
