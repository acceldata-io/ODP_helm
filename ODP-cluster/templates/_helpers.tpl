{{- define "odp.defaultCpuRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "cpu") -}}
{{- .Values.resources.requests.cpu -}}
{{- else -}}
{{- ternary "4" "6" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultMemoryRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "memory") -}}
{{- .Values.resources.requests.memory -}}
{{- else -}}
{{- ternary "16Gi" "32Gi" (eq $nodes 3) -}}
{{- end -}}
{{- end -}}

{{- define "odp.defaultEphemeralRequest" -}}
{{- $nodes := default 1 .Values.nodes | int -}}
{{- if and .Values.resources (hasKey .Values.resources "requests") (hasKey .Values.resources.requests "ephemeralStorage") -}}
{{- .Values.resources.requests.ephemeralStorage -}}
{{- else -}}
{{- ternary "100Gi" "200Gi" (eq $nodes 3) -}}
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

# Helper to get Python version based on ODP version
{{- /*
Usage: {{ include "odp.getPythonVersion" . }}
Logic:
- if odp version starts with 3.3 then pythonVersion 311
- else if version after "-" first digit is 3 then python 311
- else python2
*/ -}}
{{- define "odp.getPythonVersion" -}}
  {{- if .Values.pythonVersion -}}
    {{- .Values.pythonVersion -}}
  {{- else -}}
    {{- $OdpVersion := .Values.OdpVersion | toString -}}
    {{- if hasPrefix "3.3" $OdpVersion -}}
      {{- "311" -}}
    {{- else -}}
      {{- $parts := split "-" $OdpVersion -}}
      {{- if gt (len $parts) 1 -}}
        {{- $afterDash := index $parts 1 -}}
        {{- if hasPrefix "3" $afterDash -}}
          {{- "311" -}}
        {{- else -}}
          {{- "2" -}}
        {{- end -}}
      {{- else -}}
        {{- "2" -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

# Helper to get JDK version based on ODP version
{{- /*
Usage: {{ include "odp.getJdkVersion" . }}
Logic:
- if odp version starts with 3.3 then jdk 11
- else if version after "-" first digit is 3 then jdk 8
- else jdk 8
*/ -}}
{{- define "odp.getJdkVersion" -}}
  {{- if .Values.jdkVersion -}}
    {{- .Values.jdkVersion -}}
  {{- else -}}
    {{- $OdpVersion := .Values.OdpVersion | toString -}}
    {{- if hasPrefix "3.3" $OdpVersion -}}
      {{- "11" -}}
    {{- else -}}
      {{- "8" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

# Helper to get Docker repository with default fallback
{{- /*
Usage: {{ include "odp.getDockerRepository" . }}
Returns docker repository from .Values.dockerRepository or default
*/ -}}
{{- define "odp.getDockerRepository" -}}
  {{- .Values.dockerRepository | default "harshith212" -}}
{{- end -}}

# Helper to generate image name based on OS, Python and JDK versions
{{- /*
Usage: {{ include "odp.getImageName" . }}
Generates image name in format: {dockerRepository}/odp-{os}-py{pythonVersion}-jdk{jdkVersion}
Examples:
- harshith212/odp-rhel8-py311-jdk11
- myregistry.com/odp-ubuntu22-py2-jdk8
*/ -}}
{{- define "odp.getImageName" -}}
  {{- if .Values.image -}}
    {{- .Values.image -}}
  {{- else -}}
    {{- $dockerRepo := include "odp.getDockerRepository" . -}}
    {{- $os := .Values.OperatingSystem | default "rhel8" -}}
    {{- $pythonVersion := include "odp.getPythonVersion" . -}}
    {{- $jdkVersion := include "odp.getJdkVersion" . -}}
    {{- printf "%s/odp-%s-py%s-java%s" $dockerRepo $os $pythonVersion $jdkVersion -}}
  {{- end -}}
{{- end -}}


{{- /*
Usage: {{ include "odp.getDatabase" . }}
Logic:
- Returns the database value from .Values.Database if it's one of: mysql, postgres, oracle, mariadb
- Otherwise defaults to mysql
*/ -}}
{{- define "odp.getDatabase" -}}
  {{- $validDatabases := list "mysql" "postgres" "oracle" "mariadb" -}}
  {{- if and .Values.Database (has .Values.Database $validDatabases) -}}
    {{- .Values.Database -}}
  {{- else -}}
    {{- "mysql" -}}
  {{- end -}}
{{- end -}}
