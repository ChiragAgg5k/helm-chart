{{/*
Values that were renamed or removed, as "old.key": "what to do instead".
Setting one fails the render with that message instead of the schema's
generic "additional properties not allowed". Keep each entry, and a
permissive stub for the old key in values.schema.json, for at least one
minor release (CONTRIBUTING.md, "Deprecating a value").
*/}}
{{- define "appwrite.deprecations.renamed" -}}
assistant: Appwrite removed the assistant in 2.4.0. Delete the assistant block from your values.
storage.s3.endpoint: "moved to storage.s3.external.endpoint, with storage.s3.mode: external (the default, builtin, runs SeaweedFS in the release)."
storage.s3.region: "moved to storage.s3.external.region, with storage.s3.mode: external."
{{- end }}

{{/*
Error messages for deprecated values that are set, as a JSON list.
*/}}
{{- define "appwrite.deprecations" -}}
{{- $errors := list }}
{{- range $old, $instead := include "appwrite.deprecations.renamed" . | fromYaml }}
{{- $node := $.Values }}
{{- $found := true }}
{{- range splitList "." $old }}
{{- if and $found (kindIs "map" $node) (hasKey $node .) }}
{{- $node = get $node . }}
{{- else }}
{{- $found = false }}
{{- end }}
{{- end }}
{{- if $found }}
{{- $errors = append $errors (printf "%s is no longer supported: %s" $old $instead) }}
{{- end }}
{{- end }}
{{- toJson $errors }}
{{- end }}
