{{/*
HTTPRoute metadata and parentRefs.
Usage: include "appwrite.httpRoute.head" (dict "root" $ "name" "main" "parentRefs" (list))
*/}}
{{- define "appwrite.httpRoute.head" -}}
{{- $root := .root }}
{{- $h := $root.Values.httpRoute }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "appwrite.fullname" $root }}{{ if ne .name "main" }}-{{ .name }}{{ end }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "appwrite.labels" $root | nindent 4 }}
    {{- with $h.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with include "appwrite.annotations" (dict "root" $root "annotations" $h.annotations) | trim }}{{ . | nindent 2 }}{{ end }}
spec:
  parentRefs:
    {{- toYaml (.parentRefs | default $h.parentRefs) | nindent 4 }}
{{- end }}

{{/*
backendRefs to a component Service, plus `httpRoute.timeouts`. Realtime is
left out: a request timeout would cut its WebSockets.
*/}}
{{- define "appwrite.httpRoute.backend" -}}
backendRefs:
  - name: {{ include "appwrite.fullname" .root }}-{{ .service }}
    port: {{ .port }}
{{- if ne .service "realtime" }}
{{- with .root.Values.httpRoute.timeouts }}
timeouts:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
