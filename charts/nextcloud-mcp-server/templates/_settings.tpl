{{/*
Generated dynaconf settings.toml body — the NON-SECRET, dataclass-backed config
that the app would otherwise receive as env vars. dynaconf precedence is
env var > settings.toml > app defaults, so per-deployment env/extraEnv still
overrides anything here. Secrets (DATABASE_URL, *_API_KEY, TOKEN_ENCRYPTION_KEY,
OIDC client creds, NEXTCLOUD_PASSWORD, WEBHOOK_SECRET) and per-pod/auth-coupled
operational env (MCP_ROLE, MCP_DEPLOYMENT_MODE, INGEST_QUEUE, the auth.mode
config, the qdrant/provider config that sits next to an API key) stay in
containerEnv — they're NOT emitted here.

TYPING IS LOAD-BEARING: the app does not coerce, and dynaconf preserves a TOML
scalar's type. Strings are quoted; bool/int/float are bare. Optionals keep their
{{ "{{- if/with }}" }} guard so an unset value is OMITTED (preserving the app's
None/default) rather than written as "".

Keys are uppercased (= the env-var names) — dynaconf is case-insensitive and the
app reads each via _dget("ENV_NAME").
*/}}
{{- define "nextcloud-mcp-server.generatedSettings" -}}
[default]
# Nextcloud connection (non-secret)
NEXTCLOUD_HOST = {{ .Values.nextcloud.host | quote }}
{{- if not .Values.nextcloud.verifySsl }}
NEXTCLOUD_VERIFY_SSL = false
{{- end }}
{{- with .Values.nextcloud.caBundle }}
NEXTCLOUD_CA_BUNDLE = {{ . | quote }}
{{- end }}
# Database (non-secret config; DATABASE_URL stays a Secret env)
{{- if .Values.database.verifySsl }}
DATABASE_VERIFY_SSL = {{ .Values.database.verifySsl }}
{{- end }}
{{- if or .Values.database.caBundle .Values.database.caBundleSecret.name }}
DATABASE_CA_BUNDLE = {{ if .Values.database.caBundleSecret.name }}{{ .Values.database.caBundleSecret.mountPath | quote }}{{ else }}{{ .Values.database.caBundle | quote }}{{ end }}
{{- end }}
{{- if .Values.database.poolSize }}
DATABASE_POOL_SIZE = {{ .Values.database.poolSize }}
{{- end }}
{{- if (or (eq (toString .Values.database.maxOverflow) "0") .Values.database.maxOverflow) }}
DATABASE_MAX_OVERFLOW = {{ .Values.database.maxOverflow }}
{{- end }}
# Ingest worker (Deck #424): poll-only when behind a transaction-mode pooler
INGEST_LISTEN_NOTIFY = {{ .Values.ingest.listenNotify }}
# Document chunking (always; used by the vector-sync processor)
DOCUMENT_CHUNK_SIZE = {{ .Values.documentChunking.chunkSize }}
DOCUMENT_CHUNK_OVERLAP = {{ .Values.documentChunking.chunkOverlap }}
# Tiered PDF extraction + OCR pipeline
DOCUMENT_TIER1_ENGINE = {{ .Values.documentPipeline.tier1Engine | quote }}
DOCUMENT_CLASSIFY_ENABLED = {{ .Values.documentPipeline.classifyEnabled }}
DOCUMENT_GLYPH_CORRUPTION_RATIO = {{ .Values.documentPipeline.glyphCorruptionRatio }}
DOCUMENT_PARSE_TIMEOUT_SECONDS = {{ .Values.documentPipeline.parseTimeoutSeconds }}
DOCUMENT_PARSE_MEM_LIMIT_MB = {{ .Values.documentPipeline.parseMemLimitMb }}
DOCUMENT_PDF_GRAPHICS_LIMIT = {{ .Values.documentPipeline.pdfGraphicsLimit }}
DOCUMENT_MAX_PDF_SIZE_MB = {{ .Values.documentPipeline.maxPdfSizeMb }}
DOCUMENT_OCR_ENABLED = {{ .Values.documentPipeline.ocr.enabled }}
{{- if .Values.documentPipeline.ocr.enabled }}
DOCUMENT_OCR_PROVIDER = {{ .Values.documentPipeline.ocr.provider | quote }}
DOCUMENT_OCR_MODEL = {{ .Values.documentPipeline.ocr.model | quote }}
DOCUMENT_OCR_TIMEOUT_SECONDS = {{ .Values.documentPipeline.ocr.timeoutSeconds }}
DOCUMENT_OCR_MODE = {{ .Values.documentPipeline.ocr.mode | quote }}
DOCUMENT_OCR_BATCH_POLL_SECONDS = {{ .Values.documentPipeline.ocr.batchPollSeconds }}
DOCUMENT_OCR_BATCH_MAX_WAIT_SECONDS = {{ .Values.documentPipeline.ocr.batchMaxWaitSeconds }}
DOCUMENT_OCR_MIN_TEXT_QUALITY = {{ .Values.documentPipeline.ocr.minTextQuality }}
DOCUMENT_OCR_PAGE_FRACTION = {{ .Values.documentPipeline.ocr.pageFraction }}
DOCUMENT_OCR_MIN_PAGE_CHARS = {{ .Values.documentPipeline.ocr.minPageChars }}
DOCUMENT_OCR_DETECT_SCANNED = {{ .Values.documentPipeline.ocr.detectScanned }}
{{- end }}
# Semantic search / vector sync
ENABLE_SEMANTIC_SEARCH = {{ .Values.semanticSearch.enabled }}
{{- if .Values.semanticSearch.enabled }}
VECTOR_SYNC_SCAN_INTERVAL = {{ .Values.semanticSearch.scanInterval }}
VECTOR_SYNC_PROCESSOR_WORKERS = {{ .Values.semanticSearch.processorWorkers }}
VECTOR_SYNC_QUEUE_MAX_SIZE = {{ .Values.semanticSearch.queueMaxSize }}
{{- with .Values.semanticSearch.excludedTags }}
EXCLUDED_TAGS = {{ . | quote }}
{{- end }}
{{- end }}
# Observability
METRICS_ENABLED = {{ .Values.observability.metrics.enabled }}
METRICS_PORT = {{ .Values.observability.metrics.port }}
{{- if .Values.observability.tracing.enabled }}
OTEL_EXPORTER_OTLP_ENDPOINT = {{ .Values.observability.tracing.endpoint | quote }}
OTEL_EXPORTER_VERIFY_SSL = {{ .Values.observability.tracing.verifySsl }}
OTEL_SERVICE_NAME = {{ .Values.observability.tracing.serviceName | quote }}
OTEL_TRACES_SAMPLER = {{ .Values.observability.tracing.sampler | quote }}
OTEL_TRACES_SAMPLER_ARG = {{ .Values.observability.tracing.samplingRate }}
{{- end }}
LOG_FORMAT = {{ .Values.observability.logging.format | quote }}
LOG_LEVEL = {{ .Values.observability.logging.level | quote }}
LOG_INCLUDE_TRACE_CONTEXT = {{ .Values.observability.logging.includeTraceContext }}
{{- with .Values.settings.content }}

# --- operator-supplied extra settings (.Values.settings.content) ---
{{ . }}
{{- end }}
{{- end -}}
