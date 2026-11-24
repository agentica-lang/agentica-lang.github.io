{{- range hugo.Data.team }}
## {{ partial "text.html" (dict "item" . "field" "group") }}
{{ range .people }}
- [{{ partial "text.html" (dict "item" . "field" "name") }}]({{ .url }}): {{ partial "text.html" (dict "item" . "field" "line") }}
{{- end }}
{{ end }}
