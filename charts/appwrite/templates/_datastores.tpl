{{/*
Secret reference for a credential value ({value, secretName, secretKey}), as
YAML (name, key): the Secret you named, or the chart's Secret when it holds
the value (set inline or generated). Empty when there's no value at all.
Usage: include "appwrite.credential" (dict "root" $ "ref" .Values.redis.password "chartKey" "redis-password")
*/}}
{{- define "appwrite.credential" -}}
{{- $ref := .ref | default dict }}
{{- if $ref.secretName }}
name: {{ $ref.secretName }}
key: {{ $ref.secretKey }}
{{- else if hasKey (include "appwrite.secret.data" .root | fromYaml) .chartKey }}
name: {{ include "appwrite.secretName" .root }}
key: {{ .chartKey }}
{{- end }}
{{- end }}

{{/*
`valueFrom` for a credential, for env entries.
Usage: include "appwrite.credential.valueFrom" (dict "root" $ "ref" ... "chartKey" ...) | fromYaml
*/}}
{{- define "appwrite.credential.valueFrom" -}}
{{- with include "appwrite.credential" . | fromYaml }}
secretKeyRef:
  name: {{ .name }}
  key: {{ .key }}
{{- end }}
{{- end }}

{{/*
Connection settings for the main database, built-in or external, as YAML:
adapter, host, port, database, username, and secret (name/key) when a
password is configured.
*/}}
{{- define "appwrite.db" -}}
{{- $d := .Values.database }}
{{- $ports := dict "postgresql" "5432" "mariadb" "3306" "mysql" "3306" "mongodb" "27017" }}
{{- if eq $d.mode "builtin" }}
adapter: postgresql
host: {{ include "appwrite.componentName" (dict "root" . "component" "postgresql") }}
port: "5432"
{{- else }}
adapter: {{ $d.adapter }}
host: {{ $d.external.host }}
port: {{ $d.external.port | default (get $ports $d.adapter) | toString | quote }}
{{- end }}
database: {{ $d.name }}
username: {{ $d.username }}
{{- with include "appwrite.credential" (dict "root" . "ref" $d.password "chartKey" "db-password") }}
secret:
  {{- . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Redis connection settings, built-in or external.
*/}}
{{- define "appwrite.redis" -}}
{{- $r := .Values.redis }}
{{- if eq $r.mode "builtin" }}
host: {{ include "appwrite.componentName" (dict "root" . "component" "redis") }}
port: "6379"
username: ""
{{- else }}
host: {{ $r.external.host }}
port: {{ $r.external.port | toString | quote }}
username: {{ $r.username | quote }}
{{- end }}
{{- with include "appwrite.credential" (dict "root" . "ref" $r.password "chartKey" "redis-password") }}
secret:
  {{- . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
ClickHouse connection settings, built-in or external: scheme, address
(host:port), database, username, secret.
*/}}
{{- define "appwrite.clickhouse" -}}
{{- $c := .Values.clickhouse }}
{{- if eq $c.mode "builtin" }}
scheme: http
address: {{ include "appwrite.componentName" (dict "root" . "component" "clickhouse") }}:8123
{{- else }}
{{- $url := urlParse ($c.external.url | default "http://clickhouse:8123") }}
{{- $port := ternary "8443" "8123" (eq $url.scheme "https") }}
scheme: {{ $url.scheme }}
address: {{ ternary $url.host (printf "%s:%s" $url.host $port) (contains ":" $url.host) }}
{{- end }}
database: {{ $c.database }}
username: {{ $c.username }}
{{- with include "appwrite.credential" (dict "root" . "ref" $c.password "chartKey" "clickhouse-password") }}
secret:
  {{- . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
S3 settings for `storage.device: s3`, built-in or external, as YAML: builtin,
endpoint (a URL; empty means AWS S3), region and bucket.
*/}}
{{- define "appwrite.s3" -}}
{{- $s := .Values.storage.s3 }}
{{- if eq $s.mode "builtin" }}
builtin: true
endpoint: {{ printf "http://%s.%s.svc:8333" (include "appwrite.componentName" (dict "root" . "component" "seaweedfs")) .Release.Namespace | quote }}
region: us-east-1
{{- /* Appwrite 2.6 infers the style from the endpoint; the Service name could pass for a bucket host. */}}
pathStyle: enabled
{{- else }}
builtin: false
endpoint: {{ $s.external.endpoint | quote }}
region: {{ $s.external.region | quote }}
pathStyle: {{ $s.external.pathStyle | quote }}
{{- end }}
bucket: {{ $s.bucket | quote }}
{{- end }}

{{/*
"true" when the release runs the built-in SeaweedFS, else empty.
*/}}
{{- define "appwrite.s3.builtin" -}}
{{- if and (eq .Values.storage.device "s3") (eq .Values.storage.s3.mode "builtin") }}true{{ end }}
{{- end }}
