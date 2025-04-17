{{- define "odp.defaultCpuRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "cpu") -}}
{{- .Values.resources.requests.cpu -}}
{{- else -}}
{{- ternary "2" "4" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultMemoryRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "memory") -}}
{{- .Values.resources.requests.memory -}}
{{- else -}}
{{- ternary "8Gi" "12Gi" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultEphemeralRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "ephemeralStorage") -}}
{{- .Values.resources.requests.ephemeralStorage -}}
{{- else -}}
{{- ternary "80Gi" "100Gi" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultCpuLimit" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "limits") (hasKey .Values.resources.limits "cpu") -}}
{{- .Values.resources.limits.cpu -}}
{{- else -}}
{{- ternary "4" "6" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultMemoryLimit" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "limits") (hasKey .Values.resources.limits "memory") -}}
{{- .Values.resources.limits.memory -}}
{{- else -}}
{{- ternary "16Gi" "32Gi" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultEphemeralLimit" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "limits") (hasKey .Values.resources.limits "ephemeralStorage") -}}
{{- .Values.resources.limits.ephemeralStorage -}}
{{- else -}}
{{- ternary "100Gi" "200Gi" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}