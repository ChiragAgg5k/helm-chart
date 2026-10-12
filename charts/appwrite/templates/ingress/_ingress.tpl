{{/*
Ingress for a set of hosts.
Usage: include "appwrite.ingress" (dict "root" $ "name" "main" "hosts" (list) "paths" (list) "annotations" (dict) "tls" (dict "enabled" true "secretName" "x"))
A host of "" renders a rule without a host.
*/}}
{{- define "appwrite.ingress" -}}
{{- $root := .root }}
{{- $i := $root.Values.ingress }}
{{- $fullname := include "appwrite.fullname" $root }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}{{ if ne .name "main" }}-{{ .name }}{{ end }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "appwrite.labels" $root | nindent 4 }}
    {{- with $i.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with include "appwrite.annotations" (dict "root" $root "annotations" (merge (dict) (.annotations | default dict) ($i.annotations | default dict))) | trim }}{{ . | nindent 2 }}{{ end }}
spec:
  {{- with $i.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- $tls := list }}
  {{- if and .tls .tls.enabled }}
  {{- $tls = append $tls (dict "hosts" .hosts "secretName" .tls.secretName) }}
  {{- end }}
  {{- $tls = concat $tls (.extraTls | default list) }}
  {{- with $tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $host := .hosts }}
    - {{ if $host }}host: {{ $host | quote }}
      {{ end }}http:
        paths:
          {{- range $.paths }}
          - path: {{ .path }}
            pathType: {{ $i.pathType }}
            backend:
              service:
                name: {{ $fullname }}-{{ .service }}
                port:
                  number: {{ .port }}
          {{- end }}
    {{- end }}
{{- end }}
