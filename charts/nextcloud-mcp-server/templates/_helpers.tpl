{{/*
Expand the name of the chart.
*/}}
{{- define "nextcloud-mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nextcloud-mcp-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nextcloud-mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nextcloud-mcp-server.labels" -}}
helm.sh/chart: {{ include "nextcloud-mcp-server.chart" . }}
{{ include "nextcloud-mcp-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nextcloud-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nextcloud-mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nextcloud-mcp-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nextcloud-mcp-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for basic auth
*/}}
{{- define "nextcloud-mcp-server.basicAuthSecretName" -}}
{{- if .Values.auth.basic.existingSecret }}
{{- .Values.auth.basic.existingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-basic-auth
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for multi-user basic auth
*/}}
{{- define "nextcloud-mcp-server.multiUserBasicSecretName" -}}
{{- if .Values.auth.multiUserBasic.existingSecret }}
{{- .Values.auth.multiUserBasic.existingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-multi-user-basic
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use for multi-user basic token storage
*/}}
{{- define "nextcloud-mcp-server.multiUserBasicPvcName" -}}
{{- if .Values.auth.multiUserBasic.persistence.existingClaim }}
{{- .Values.auth.multiUserBasic.persistence.existingClaim }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-token-storage
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for OAuth
*/}}
{{- define "nextcloud-mcp-server.oauthSecretName" -}}
{{- if .Values.auth.oauth.existingSecret }}
{{- .Values.auth.oauth.existingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-oauth
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for Login Flow v2
*/}}
{{- define "nextcloud-mcp-server.loginFlowSecretName" -}}
{{- if .Values.auth.loginFlow.existingSecret }}
{{- .Values.auth.loginFlow.existingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-login-flow
{{- end }}
{{- end }}

{{/*
Create the name of the Secret to use for Login Flow v2 OIDC client creds.
Falls back to loginFlowSecretName when oidcExistingSecret is not set, so the
common case (single Secret holding both token-encryption-key and OIDC creds)
just works. Override `oidcExistingSecret` to point at a separate Secret
provisioned by a different controller.
*/}}
{{- define "nextcloud-mcp-server.loginFlowOidcSecretName" -}}
{{- if .Values.auth.loginFlow.oidcExistingSecret }}
{{- .Values.auth.loginFlow.oidcExistingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.loginFlowSecretName" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use for OAuth / Login Flow storage
*/}}
{{- define "nextcloud-mcp-server.oauthPvcName" -}}
{{- if and (eq .Values.auth.mode "login-flow") .Values.auth.loginFlow.persistence.existingClaim }}
{{- .Values.auth.loginFlow.persistence.existingClaim }}
{{- else if .Values.auth.oauth.persistence.existingClaim }}
{{- .Values.auth.oauth.persistence.existingClaim }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-oauth-storage
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use for Qdrant local persistent storage
*/}}
{{- define "nextcloud-mcp-server.qdrantPvcName" -}}
{{- if .Values.qdrant.localPersistence.existingClaim }}
{{- .Values.qdrant.localPersistence.existingClaim }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-qdrant-data
{{- end }}
{{- end }}

{{/*
Create the name of the PVC to use for /app/data storage
*/}}
{{- define "nextcloud-mcp-server.dataStoragePvcName" -}}
{{- if .Values.dataStorage.existingClaim }}
{{- .Values.dataStorage.existingClaim }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-data-storage
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use for Qdrant sidecar API key
*/}}
{{- define "nextcloud-mcp-server.qdrantSidecarSecretName" -}}
{{- if .Values.qdrant.sidecar.existingSecret }}
{{- .Values.qdrant.sidecar.existingSecret }}
{{- else }}
{{- include "nextcloud-mcp-server.fullname" . }}-qdrant-sidecar
{{- end }}
{{- end }}

{{/*
Determine if data storage PVC should be enabled (backward compatible)
Checks new dataStorage.enabled OR legacy persistence configs.

ADR-026 follow-up: when the operator wires `database.url` /
`database.existingSecret`, the MCP server stops writing tokens to
the local tokens.db and the data-storage PVC is dead weight. Skip
the auth-mode-driven auto-enable in that case (the explicit
`dataStorage.enabled: true` path still wins, in case someone is
running the database backend AND wants on-disk space for, say,
attachment caching). qdrant.mode sidecar/persistent still pin
data-storage on regardless — that data lives outside the
database backend.
*/}}
{{- define "nextcloud-mcp-server.dataStorageEnabled" -}}
{{- $dbConfigured := or .Values.database.url .Values.database.existingSecret -}}
{{- if .Values.dataStorage.enabled -}}
true
{{- else if and (eq .Values.auth.mode "multi-user-basic") .Values.auth.multiUserBasic.enableOfflineAccess .Values.auth.multiUserBasic.persistence.enabled (not $dbConfigured) -}}
true
{{- else if and (eq .Values.auth.mode "login-flow") (not $dbConfigured) -}}
true
{{- else if and (eq .Values.qdrant.mode "persistent") .Values.qdrant.localPersistence.enabled -}}
true
{{- else if eq .Values.qdrant.mode "sidecar" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Check if legacy multi-user-basic persistence config is being used
*/}}
{{- define "nextcloud-mcp-server.legacyMultiUserBasicPersistence" -}}
{{- if and (eq .Values.auth.mode "multi-user-basic") .Values.auth.multiUserBasic.enableOfflineAccess .Values.auth.multiUserBasic.persistence.enabled (not .Values.dataStorage.enabled) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Check if legacy qdrant persistence config is being used
*/}}
{{- define "nextcloud-mcp-server.legacyQdrantPersistence" -}}
{{- if and (eq .Values.qdrant.mode "persistent") .Values.qdrant.localPersistence.enabled (not .Values.dataStorage.enabled) -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Return the MCP server port
*/}}
{{- define "nextcloud-mcp-server.port" -}}
{{- .Values.mcp.port }}
{{- end }}

{{/*
Return the image tag (always uses chart appVersion)
*/}}
{{- define "nextcloud-mcp-server.imageTag" -}}
{{- .Chart.AppVersion }}
{{- end }}

{{/*
Return the public issuer URL for OAuth
Defaults to nextcloud.host if not specified
*/}}
{{- define "nextcloud-mcp-server.publicIssuerUrl" -}}
{{- if .Values.nextcloud.publicIssuerUrl }}
{{- .Values.nextcloud.publicIssuerUrl }}
{{- else }}
{{- .Values.nextcloud.host }}
{{- end }}
{{- end }}

{{/*
Return the MCP server URL for OAuth callbacks
If not specified:
  - Uses ingress host if ingress is enabled
  - Otherwise defaults to http://localhost:8000 (for port-forward setups)
*/}}
{{- define "nextcloud-mcp-server.mcpServerUrl" -}}
{{- if .Values.nextcloud.mcpServerUrl }}
{{- .Values.nextcloud.mcpServerUrl }}
{{- else if .Values.ingress.enabled }}
{{- $host := index .Values.ingress.hosts 0 }}
{{- if .Values.ingress.tls }}
{{- printf "https://%s" $host.host }}
{{- else }}
{{- printf "http://%s" $host.host }}
{{- end }}
{{- else }}
{{- printf "http://localhost:%d" (int .Values.mcp.port) }}
{{- end }}
{{- end }}

{{/*
Shared container env for the API Deployment and the ingest worker Deployment.
Both roles get the identical env; INGEST_QUEUE and MCP_ROLE are layered on
per-Deployment by the caller. Extracted verbatim from the API deployment so
both pods stay in lock-step (Deck #183).
*/}}
{{- define "nextcloud-mcp-server.containerEnv" }}
            # Nextcloud connection
            - name: NEXTCLOUD_HOST
              value: {{ .Values.nextcloud.host | quote }}
            {{- if or .Values.database.url .Values.database.existingSecret }}
            # Centralized database backend (ADR-026). Wins over the
            # TOKEN_STORAGE_DB local-SQLite path that each auth mode sets
            # below; the MCP server reads DATABASE_URL first and falls back
            # to TOKEN_STORAGE_DB only when DATABASE_URL is unset.
            - name: DATABASE_URL
              {{- if .Values.database.existingSecret }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.database.existingSecret | quote }}
                  key: {{ .Values.database.existingSecretKey | quote }}
              {{- else }}
              value: {{ .Values.database.url | quote }}
              {{- end }}
            {{- end }}
            {{- if .Values.database.verifySsl }}
            - name: DATABASE_VERIFY_SSL
              value: {{ .Values.database.verifySsl | quote }}
            {{- end }}
            {{- if or .Values.database.caBundle .Values.database.caBundleSecret.name }}
            - name: DATABASE_CA_BUNDLE
              # When caBundleSecret is set, point at the mounted Secret
              # path; otherwise honor the operator-supplied path directly.
              value: {{ if .Values.database.caBundleSecret.name -}}
                     {{ .Values.database.caBundleSecret.mountPath | quote }}
                     {{- else -}}
                     {{ .Values.database.caBundle | quote }}
                     {{- end }}
            {{- end }}
            {{- if .Values.database.poolSize }}
            - name: DATABASE_POOL_SIZE
              value: {{ .Values.database.poolSize | quote }}
            {{- end }}
            {{- if (or (eq (toString .Values.database.maxOverflow) "0") .Values.database.maxOverflow) }}
            - name: DATABASE_MAX_OVERFLOW
              value: {{ .Values.database.maxOverflow | quote }}
            {{- end }}
            {{- if eq .Values.auth.mode "basic" }}
            # Basic auth mode (single-user). MCP_DEPLOYMENT_MODE is the
            # single source of truth for the server's auth flow (ADR-022);
            # being explicit here matches the loud-fail behaviour in
            # nextcloud_mcp_server.config.__post_init__ that rejects the
            # legacy ENABLE_* env vars.
            - name: MCP_DEPLOYMENT_MODE
              value: "single_user_basic"
            - name: NEXTCLOUD_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.basicAuthSecretName" . }}
                  key: {{ .Values.auth.basic.usernameKey }}
            - name: NEXTCLOUD_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.basicAuthSecretName" . }}
                  key: {{ .Values.auth.basic.passwordKey }}
            {{- else if eq .Values.auth.mode "multi-user-basic" }}
            # Multi-user BasicAuth mode (pass-through). Replaces the
            # legacy ENABLE_MULTI_USER_BASIC_AUTH env var that the server
            # now loud-fails on (ADR-022 follow-up).
            - name: MCP_DEPLOYMENT_MODE
              value: "multi_user_basic"
            - name: NEXTCLOUD_MCP_SERVER_URL
              value: {{ include "nextcloud-mcp-server.mcpServerUrl" . | quote }}
            - name: NEXTCLOUD_PUBLIC_ISSUER_URL
              value: {{ include "nextcloud-mcp-server.publicIssuerUrl" . | quote }}
            {{- if .Values.auth.multiUserBasic.enableOfflineAccess }}
            # Background operations with app passwords (replaces deprecated ENABLE_OFFLINE_ACCESS)
            - name: ENABLE_BACKGROUND_OPERATIONS
              value: "true"
            - name: TOKEN_STORAGE_DB
              value: {{ .Values.auth.multiUserBasic.tokenStorageDb | quote }}
            - name: TOKEN_ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.multiUserBasicSecretName" . }}
                  key: {{ .Values.auth.multiUserBasic.tokenEncryptionKeyKey }}
            - name: NEXTCLOUD_OIDC_SCOPES
              value: {{ .Values.auth.multiUserBasic.scopes | quote }}
            {{- if or .Values.auth.multiUserBasic.clientId .Values.auth.multiUserBasic.existingSecret }}
            # Static OAuth credentials (optional - uses DCR if not provided)
            - name: NEXTCLOUD_OIDC_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.multiUserBasicSecretName" . }}
                  key: {{ .Values.auth.multiUserBasic.clientIdKey }}
            - name: NEXTCLOUD_OIDC_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.multiUserBasicSecretName" . }}
                  key: {{ .Values.auth.multiUserBasic.clientSecretKey }}
            {{- end }}
            {{- end }}
            {{- else if eq .Values.auth.mode "oauth" }}
            # OAuth mode
            - name: NEXTCLOUD_MCP_SERVER_URL
              value: {{ include "nextcloud-mcp-server.mcpServerUrl" . | quote }}
            - name: NEXTCLOUD_PUBLIC_ISSUER_URL
              value: {{ include "nextcloud-mcp-server.publicIssuerUrl" . | quote }}
            - name: NEXTCLOUD_OIDC_SCOPES
              value: {{ .Values.auth.oauth.scopes | quote }}
            {{- if or .Values.auth.oauth.clientId .Values.auth.oauth.existingSecret }}
            - name: NEXTCLOUD_OIDC_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.oauthSecretName" . }}
                  key: {{ .Values.auth.oauth.clientIdKey }}
            - name: NEXTCLOUD_OIDC_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.oauthSecretName" . }}
                  key: {{ .Values.auth.oauth.clientSecretKey }}
            {{- end }}
            {{- else if eq .Values.auth.mode "login-flow" }}
            # Login Flow v2 mode (ADR-022). Replaces the legacy
            # ENABLE_LOGIN_FLOW env var that the server now loud-fails
            # on if set to a truthy value.
            - name: MCP_DEPLOYMENT_MODE
              value: "login_flow"
            - name: NEXTCLOUD_MCP_SERVER_URL
              value: {{ include "nextcloud-mcp-server.mcpServerUrl" . | quote }}
            - name: NEXTCLOUD_PUBLIC_ISSUER_URL
              value: {{ include "nextcloud-mcp-server.publicIssuerUrl" . | quote }}
            - name: TOKEN_STORAGE_DB
              value: {{ .Values.auth.loginFlow.tokenStorageDb | quote }}
            - name: TOKEN_ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.loginFlowSecretName" . }}
                  key: {{ .Values.auth.loginFlow.tokenEncryptionKeyKey }}
            {{- if or .Values.auth.loginFlow.clientId .Values.auth.loginFlow.oidcExistingSecret }}
            # OIDC client creds. The MCP-client ↔ MCP-server leg uses
            # OAuth/OIDC; the server's setup_oauth_config requires
            # NEXTCLOUD_OIDC_CLIENT_ID / _SECRET unless the OIDC provider
            # supports Dynamic Client Registration. Set clientId (inline)
            # or oidcExistingSecret to opt in. Static-creds users where
            # token-encryption-key + OIDC creds live in one Secret should
            # set both `existingSecret` and `oidcExistingSecret` to that
            # Secret name.
            - name: NEXTCLOUD_OIDC_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.loginFlowOidcSecretName" . }}
                  key: {{ .Values.auth.loginFlow.clientIdKey }}
            - name: NEXTCLOUD_OIDC_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.loginFlowOidcSecretName" . }}
                  key: {{ .Values.auth.loginFlow.clientSecretKey }}
            {{- end }}
            {{- end }}
            {{- with .Values.auth.oidc.discoveryUrl }}
            # OIDC discovery URL advertised to MCP clients via /api/v1/status
            # so they can skip their own localhost-based discovery fallback.
            - name: OIDC_DISCOVERY_URL
              value: {{ . | quote }}
            {{- end }}
            {{- if .Values.documentProcessing.enabled }}
            # Document processing
            - name: ENABLE_DOCUMENT_PROCESSING
              value: {{ .Values.documentProcessing.enabled | quote }}
            - name: DOCUMENT_PROCESSOR
              value: {{ .Values.documentProcessing.defaultProcessor | quote }}
            - name: PROGRESS_INTERVAL
              value: {{ .Values.documentProcessing.progressInterval | quote }}
            {{- if .Values.documentProcessing.unstructured.enabled }}
            - name: ENABLE_UNSTRUCTURED
              value: "true"
            - name: UNSTRUCTURED_API_URL
              value: {{ .Values.documentProcessing.unstructured.apiUrl | quote }}
            - name: UNSTRUCTURED_TIMEOUT
              value: {{ .Values.documentProcessing.unstructured.timeout | quote }}
            - name: UNSTRUCTURED_STRATEGY
              value: {{ .Values.documentProcessing.unstructured.strategy | quote }}
            - name: UNSTRUCTURED_LANGUAGES
              value: {{ .Values.documentProcessing.unstructured.languages | quote }}
            {{- end }}
            {{- if .Values.documentProcessing.tesseract.enabled }}
            - name: ENABLE_TESSERACT
              value: "true"
            {{- if .Values.documentProcessing.tesseract.cmd }}
            - name: TESSERACT_CMD
              value: {{ .Values.documentProcessing.tesseract.cmd | quote }}
            {{- end }}
            - name: TESSERACT_LANG
              value: {{ .Values.documentProcessing.tesseract.lang | quote }}
            {{- end }}
            {{- if .Values.documentProcessing.custom.enabled }}
            - name: ENABLE_CUSTOM_PROCESSOR
              value: "true"
            - name: CUSTOM_PROCESSOR_NAME
              value: {{ .Values.documentProcessing.custom.name | quote }}
            - name: CUSTOM_PROCESSOR_URL
              value: {{ .Values.documentProcessing.custom.url | quote }}
            {{- if .Values.documentProcessing.custom.apiKey }}
            - name: CUSTOM_PROCESSOR_API_KEY
              value: {{ .Values.documentProcessing.custom.apiKey | quote }}
            {{- end }}
            - name: CUSTOM_PROCESSOR_TIMEOUT
              value: {{ .Values.documentProcessing.custom.timeout | quote }}
            - name: CUSTOM_PROCESSOR_TYPES
              value: {{ .Values.documentProcessing.custom.types | quote }}
            {{- end }}
            {{- end }}
            # Semantic Search (replaces deprecated VECTOR_SYNC_ENABLED)
            - name: ENABLE_SEMANTIC_SEARCH
              value: {{ .Values.semanticSearch.enabled | quote }}
            {{- if .Values.semanticSearch.enabled }}
            - name: VECTOR_SYNC_SCAN_INTERVAL
              value: {{ .Values.semanticSearch.scanInterval | quote }}
            - name: VECTOR_SYNC_PROCESSOR_WORKERS
              value: {{ .Values.semanticSearch.processorWorkers | quote }}
            - name: VECTOR_SYNC_QUEUE_MAX_SIZE
              value: {{ .Values.semanticSearch.queueMaxSize | quote }}
            {{- end }}
            # Document Chunking (always set, used by vector sync processor)
            - name: DOCUMENT_CHUNK_SIZE
              value: {{ .Values.documentChunking.chunkSize | quote }}
            - name: DOCUMENT_CHUNK_OVERLAP
              value: {{ .Values.documentChunking.chunkOverlap | quote }}
            # Qdrant Vector Database
            {{- if eq .Values.qdrant.mode "network" }}
            # Network mode: Use dedicated Qdrant service
            {{- if .Values.qdrant.networkMode.deploySubchart }}
            - name: QDRANT_URL
              value: "http://{{ .Release.Name }}-qdrant:6333"
            {{- else if .Values.qdrant.networkMode.externalUrl }}
            - name: QDRANT_URL
              value: {{ .Values.qdrant.networkMode.externalUrl | quote }}
            {{- end }}
            {{- if or .Values.qdrant.networkMode.apiKey .Values.qdrant.networkMode.existingSecret }}
            - name: QDRANT_API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.qdrant.networkMode.existingSecret | default (printf "%s-qdrant" .Release.Name) }}
                  key: {{ .Values.qdrant.networkMode.secretKey }}
            {{- end }}
            {{- else if eq .Values.qdrant.mode "sidecar" }}
            # Sidecar mode: Qdrant runs in the same pod, reachable on localhost
            - name: QDRANT_URL
              value: "http://localhost:6333"
            {{- if or .Values.qdrant.sidecar.apiKey .Values.qdrant.sidecar.existingSecret }}
            - name: QDRANT_API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "nextcloud-mcp-server.qdrantSidecarSecretName" . }}
                  key: {{ .Values.qdrant.sidecar.secretKey }}
            {{- end }}
            {{- else if eq .Values.qdrant.mode "persistent" }}
            # Persistent local mode: File-based storage
            - name: QDRANT_LOCATION
              value: {{ .Values.qdrant.localPersistence.dataPath | quote }}
            {{- else }}
            # In-memory mode (default): Ephemeral storage
            - name: QDRANT_LOCATION
              value: ":memory:"
            {{- end }}
            - name: QDRANT_COLLECTION
              value: {{ .Values.qdrant.collection | quote }}
            # Ollama Embedding Service
            {{- if or .Values.ollama.enabled .Values.ollama.url }}
            - name: OLLAMA_BASE_URL
              value: {{ .Values.ollama.url | default (printf "http://%s-ollama:11434" .Release.Name) | quote }}
            - name: OLLAMA_EMBEDDING_MODEL
              value: {{ .Values.ollama.embeddingModel | quote }}
            - name: OLLAMA_VERIFY_SSL
              value: {{ .Values.ollama.verifySsl | quote }}
            {{- end }}
            # OpenAI Embedding Provider (alternative to Ollama)
            {{- if .Values.openai.enabled }}
            - name: OPENAI_API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.openai.existingSecret | default (printf "%s-openai" (include "nextcloud-mcp-server.fullname" .)) }}
                  key: {{ .Values.openai.secretKey }}
            {{- if .Values.openai.baseUrl }}
            - name: OPENAI_BASE_URL
              value: {{ .Values.openai.baseUrl | quote }}
            {{- end }}
            {{- end }}
            # Mistral Embedding Provider (first-class, distinct from OpenAI)
            {{- if .Values.mistral.enabled }}
            - name: MISTRAL_API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.mistral.existingSecret | default (printf "%s-mistral" (include "nextcloud-mcp-server.fullname" .)) }}
                  key: {{ .Values.mistral.secretKey }}
            {{- if .Values.mistral.embeddingModel }}
            - name: MISTRAL_EMBEDDING_MODEL
              value: {{ .Values.mistral.embeddingModel | quote }}
            {{- end }}
            {{- if .Values.mistral.baseUrl }}
            - name: MISTRAL_BASE_URL
              value: {{ .Values.mistral.baseUrl | quote }}
            {{- end }}
            {{- end }}
            # Observability
            - name: METRICS_ENABLED
              value: {{ .Values.observability.metrics.enabled | quote }}
            - name: METRICS_PORT
              value: {{ .Values.observability.metrics.port | quote }}
            {{- if .Values.observability.tracing.enabled }}
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: {{ .Values.observability.tracing.endpoint | quote }}
            - name: OTEL_SERVICE_NAME
              value: {{ .Values.observability.tracing.serviceName | quote }}
            - name: OTEL_TRACES_SAMPLER_ARG
              value: {{ .Values.observability.tracing.samplingRate | quote }}
            {{- end }}
            - name: LOG_FORMAT
              value: {{ .Values.observability.logging.format | quote }}
            - name: LOG_LEVEL
              value: {{ .Values.observability.logging.level | quote }}
            - name: LOG_INCLUDE_TRACE_CONTEXT
              value: {{ .Values.observability.logging.includeTraceContext | quote }}
            {{- with .Values.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
{{- end }}
