{{- range hugo.Data.ecosystem }}
## {{ partial "text.html" (dict "item" . "field" "group") }}
{{ range .projects }}
- [{{ partial "text.html" (dict "item" . "field" "name") }}]({{ .url | absURL }}): {{ partial "text.html" (dict "item" . "field" "description") }}
{{- range .highlights }}
  - [{{ partial "text.html" (dict "item" . "field" "name") }}]({{ .url | absURL }}){{ if .unreleased }} (unreleased){{ end }}: {{ partial "text.html" (dict "item" . "field" "description") }}
{{- end }}
{{- end }}
{{ end }}
