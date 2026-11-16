{{- range hugo.Data.ecosystem }}
## {{ .group }}
{{ range .projects }}
- [{{ .name }}]({{ .url | absURL }}): {{ .description }}
{{- range .highlights }}
  - [{{ .name }}]({{ .url | absURL }}): {{ .description }}
{{- end }}
{{- end }}
{{ end }}
