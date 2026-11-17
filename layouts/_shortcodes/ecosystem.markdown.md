{{- range hugo.Data.ecosystem }}
## {{ .group }}
{{ range .projects }}
- [{{ .name }}]({{ .url | absURL }}): {{ .description }}
{{- range .highlights }}
  - [{{ .name }}]({{ .url | absURL }}){{ if .unreleased }} (unreleased){{ end }}: {{ .description }}
{{- end }}
{{- end }}
{{ end }}
