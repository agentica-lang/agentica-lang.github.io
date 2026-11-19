{{- range hugo.Data.ecosystem }}
## {{ partial "text.html" (dict "item" . "field" "group") }}
{{ range .projects }}
- [{{ .name }}]({{ .url | absURL }}): {{ partial "text.html" (dict "item" . "field" "description") }}
{{- range .highlights }}
  - [{{ .name }}]({{ .url | absURL }}){{ if .unreleased }} (unreleased){{ end }}: {{ partial "text.html" (dict "item" . "field" "description") }}
{{- end }}
{{- end }}
{{ end }}
