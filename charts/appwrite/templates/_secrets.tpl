{{/*
Data of the chart-managed Secret, as YAML (key: base64 value).

Generated values are created once and then reused: the existing Secret is
read back with `lookup` on every upgrade. Without cluster access (`helm
template`, Argo CD) lookup returns nothing, so set
`appwrite.secrets.generate: false` there and provide existing Secrets.
*/}}
{{- define "appwrite.secret.data" -}}
{{- if not (hasKey .Values "__secretData") }}
{{- $existing := (lookup "v1" "Secret" .Release.Namespace (include "appwrite.secretName" .)).data | default dict }}
{{- $data := dict }}
{{- $s := .Values.appwrite.secrets }}
{{- if not $s.existingSecret }}
{{- range $key, $explicit := dict "_APP_OPENSSL_KEY_V1" $s.opensslKey "_APP_NOTIFICATIONS_TRACKING_SECRET" $s.trackingSecret "_APP_GEO_SECRET" $s.geoSecret }}
{{- $_ := set $data $key (include "appwrite.secret.value" (dict "root" $ "existing" $existing "key" $key "explicit" $explicit)) }}
{{- end }}
{{- end }}
{{- $cs := .Values.compute.secrets }}
{{- if and .Values.compute.enabled (not $cs.existingSecret) }}
{{- range $key, $explicit := dict "executor-secret" $cs.executorSecret "orchestrator-secret" $cs.orchestratorSecret }}
{{- $_ := set $data $key (include "appwrite.secret.value" (dict "root" $ "existing" $existing "key" $key "explicit" $explicit)) }}
{{- end }}
{{- end }}
{{- /*
Credentials ({value, secretName, secretKey}): [value, chart Secret key, in use, generate when empty].
One with a secretName lives in that Secret; the chart stores the others.
*/}}
{{- $v := .Values }}
{{- $s3 := eq $v.storage.device "s3" }}
{{- $credentials := list
  (list $v.database.password "db-password" true (eq $v.database.mode "builtin"))
  (list $v.redis.password "redis-password" true (and (eq $v.redis.mode "builtin") $v.redis.builtin.requirePassword))
  (list $v.clickhouse.password "clickhouse-password" true (eq $v.clickhouse.mode "builtin"))
  (list $v.documentsDb.password "documentsdb-password" $v.documentsDb.enabled false)
  (list $v.vectorsDb.password "vectorsdb-password" $v.vectorsDb.enabled false)
  (list $v.storage.s3.accessKeyId "s3-access-key" $s3 false)
  (list $v.storage.s3.secretAccessKey "s3-secret-key" $s3 false)
  (list $v.smtp.password "smtp-password" true false) }}
{{- range $credentials }}
{{- $ref := index . 0 }}
{{- $key := index . 1 }}
{{- if and (index . 2) (not $ref.secretName) }}
{{- if index . 3 }}
{{- $_ := set $data $key (include "appwrite.secret.value" (dict "root" $ "existing" $existing "key" $key "explicit" $ref.value)) }}
{{- else if $ref.value }}
{{- $_ := set $data $key ($ref.value | toString | b64enc) }}
{{- end }}
{{- end }}
{{- end }}
{{- /* Cache the result: random values must be identical everywhere this is included. */}}
{{- $_ := set .Values "__secretData" $data }}
{{- end }}
{{- toYaml (get .Values "__secretData") }}
{{- end }}

{{/*
Base64 value for one generated credential: the explicit value, else the
value already stored in the cluster, else a new random value.
*/}}
{{- define "appwrite.secret.value" -}}
{{- $current := get .existing .key }}
{{- if and (not $current) (eq .key "db-password") }}
{{- /* Installs from before the values restructure stored it as postgres-password. */}}
{{- $current = get .existing "postgres-password" }}
{{- end }}
{{- if .explicit }}
{{- if and $current (eq .key "_APP_OPENSSL_KEY_V1") (ne (b64dec $current) .explicit) (not .root.Values.appwrite.secrets.allowKeyRotation) }}
{{- fail "appwrite.secrets.opensslKey differs from the key stored in the cluster. Changing _APP_OPENSSL_KEY_V1 makes encrypted data unreadable. Set appwrite.secrets.allowKeyRotation=true only if you know what you are doing." }}
{{- end }}
{{- .explicit | toString | b64enc }}
{{- else if $current }}
{{- $current }}
{{- else if not .root.Values.appwrite.secrets.generate }}
{{- fail (printf "No value for %s: provide it explicitly or through an existing Secret (appwrite.secrets.generate is false)." .key) }}
{{- else if and .root.Release.IsUpgrade (eq .key "_APP_OPENSSL_KEY_V1") }}
{{- fail (printf "Refusing to generate a new _APP_OPENSSL_KEY_V1 during an upgrade: Secret %s/%s was not found. Restore it, or set appwrite.secrets.existingSecret or appwrite.secrets.opensslKey. With --dry-run, use --dry-run=server so the existing Secret can be read." .root.Release.Namespace (include "appwrite.secretName" .root)) }}
{{- else if and .root.Release.IsUpgrade (not .existing) (eq .key "db-password") }}
{{- /* PostgreSQL writes the password into the data volume on first start: a new one wouldn't match it. */}}
{{- fail (printf "Refusing to generate a new %s during an upgrade: Secret %s/%s was not found, and the existing data volume keeps the old password. Restore the Secret, or set the password explicitly. With --dry-run, use --dry-run=server so the existing Secret can be read." .key .root.Release.Namespace (include "appwrite.secretName" .root)) }}
{{- else }}
{{- randAlphaNum 48 | b64enc }}
{{- end }}
{{- end }}

{{/*
Data of the executor's Secret in its own namespace, as YAML (key: base64
value): the executor secret and the S3 credentials from the chart Secret.
*/}}
{{- define "appwrite.executor.secret.data" -}}
{{- $data := include "appwrite.secret.data" . | fromYaml }}
{{- dict
  "executor-secret" (get $data "executor-secret")
  "s3-access-key" (get $data "s3-access-key")
  "s3-secret-key" (get $data "s3-secret-key")
  | toYaml }}
{{- end }}
