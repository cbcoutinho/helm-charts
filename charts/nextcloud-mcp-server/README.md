# Nextcloud MCP Server Helm Chart

This Helm chart deploys the Nextcloud MCP (Model Context Protocol) Server on a Kubernetes cluster, enabling AI assistants to interact with your Nextcloud instance.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A running Nextcloud instance (accessible from the Kubernetes cluster)
- Nextcloud credentials (username/password for basic auth OR OAuth client for OAuth mode)

## Installation

### Quick Start with Basic Authentication

```bash
# Add the Helm repository
helm repo add nextcloud-mcp https://cbcoutinho.github.io/nextcloud-mcp-server
helm repo update

# Install with basic auth (recommended for most users)
helm install nextcloud-mcp nextcloud-mcp/nextcloud-mcp-server \
  --set nextcloud.host=https://cloud.example.com \
  --set auth.basic.username=myuser \
  --set auth.basic.password=mypassword
```

### Using a values file

Create a `custom-values.yaml` file:

```yaml
nextcloud:
  host: https://cloud.example.com

auth:
  mode: basic
  basic:
    username: myuser
    password: mypassword

resources:
  limits:
    cpu: 1000m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

Install with your custom values:

```bash
helm install nextcloud-mcp nextcloud-mcp/nextcloud-mcp-server -f custom-values.yaml
```

### OAuth Authentication Mode (Experimental)

**Warning:** OAuth mode is experimental and requires patches to the Nextcloud `user_oidc` app. See the [Authentication Guide](https://github.com/cbcoutinho/nextcloud-mcp-server#authentication) for details.

```yaml
nextcloud:
  host: https://cloud.example.com
  mcpServerUrl: https://mcp.example.com
  publicIssuerUrl: https://cloud.example.com

auth:
  mode: oauth
  oauth:
    # Optional: provide pre-registered client credentials
    # If not provided, will use Dynamic Client Registration
    clientId: "your-client-id"
    clientSecret: "your-client-secret"
    persistence:
      enabled: true
      size: 100Mi

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: mcp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: nextcloud-mcp-tls
      hosts:
        - mcp.example.com
```

## Configuration

### Key Configuration Parameters

#### Nextcloud Connection

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nextcloud.host` | URL of your Nextcloud instance (required) | `""` |
| `nextcloud.mcpServerUrl` | MCP server URL for OAuth callbacks (OAuth only, optional) | Smart default* |
| `nextcloud.publicIssuerUrl` | Public URL for browser-accessible OAuth authorization endpoint (OAuth only, optional) | Smart default** |
| `nextcloud.verifySsl` | Verify TLS certificates when connecting to Nextcloud (`NEXTCLOUD_VERIFY_SSL`) | `true` |
| `nextcloud.caBundle` | In-container path to a PEM CA bundle for a private CA (`NEXTCLOUD_CA_BUNDLE`); mount the file via `volumes`/`volumeMounts` | `""` |

**Smart Defaults:**
- `*mcpServerUrl`: If not set, automatically uses ingress host (if enabled) or `http://localhost:8000` (for port-forward setups)
- `**publicIssuerUrl`: If not set, defaults to `nextcloud.host`. **Only used for authorization endpoints** that browsers must access. All server-to-server endpoints (token, JWKS, introspection, userinfo) use URLs from OIDC discovery without rewriting

#### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.mode` | Authentication mode: `basic` or `oauth` | `basic` |
| `auth.basic.username` | Nextcloud username (basic auth) | `""` |
| `auth.basic.password` | Nextcloud password (basic auth) | `""` |
| `auth.basic.existingSecret` | Use existing secret for credentials | `""` |
| `auth.oauth.clientId` | OAuth client ID (OAuth mode, optional) | `""` |
| `auth.oauth.clientSecret` | OAuth client secret (OAuth mode, optional) | `""` |
| `auth.oauth.persistence.enabled` | Enable persistent storage for OAuth | `true` |
| `auth.oauth.persistence.size` | Size of OAuth storage PVC | `100Mi` |
| `auth.oidc.discoveryUrl` | OIDC discovery URL advertised on `/api/v1/status` (mode-agnostic); set to your Nextcloud OIDC discovery URL so MCP clients on managed NC skip their localhost discovery fallback | `""` |

#### Data Storage

The `/app/data` directory is used for application data (token databases, Qdrant persistent storage, etc.). It is always mounted as writable to support the read-only root filesystem security context.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dataStorage.enabled` | Enable persistent storage for `/app/data` | `false` |
| `dataStorage.size` | Size of data storage PVC | `1Gi` |
| `dataStorage.storageClass` | Storage class (leave empty for default) | `""` |
| `dataStorage.accessMode` | Access mode | `ReadWriteOnce` |
| `dataStorage.existingClaim` | Use existing PVC | `""` |

**When to enable persistence:**
- Multi-user basic auth with offline access (stores `tokens.db`)
- Qdrant persistent mode (stores vector database)
- Any feature requiring persistent app data

**When persistence is disabled:** Uses `emptyDir` (non-persistent, data lost on pod restart, but directory remains writable).

#### MCP Server Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mcp.transport` | Transport mode | `streamable-http` |
| `mcp.port` | Server port (used by both auth modes) | `8000` |
| `mcp.extraArgs` | Additional command-line arguments | `[]` |

The `extraArgs` parameter allows you to pass additional command-line arguments to the MCP server. This is useful for enabling debug logging, enabling specific apps, or other runtime configuration.

**Example:**
```yaml
mcp:
  extraArgs:
    - "--log-level"
    - "debug"
    - "--enable-app"
    - "notes"
```

#### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `ghcr.io/cbcoutinho/nextcloud-mcp-server` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

**Note:** Image tag is automatically set to the chart's `appVersion` and cannot be overridden.

#### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |

#### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8000` |

#### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts` | Ingress host configuration | See values.yaml |
| `ingress.tls` | Ingress TLS configuration | `[]` |

#### Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `80` |

#### Health Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe.httpGet.path` | Liveness probe endpoint | `/health/live` |
| `livenessProbe.initialDelaySeconds` | Initial delay for liveness | `30` |
| `livenessProbe.periodSeconds` | Check interval for liveness | `10` |
| `readinessProbe.httpGet.path` | Readiness probe endpoint | `/health/ready` |
| `readinessProbe.initialDelaySeconds` | Initial delay for readiness | `10` |
| `readinessProbe.periodSeconds` | Check interval for readiness | `5` |

The application exposes HTTP health check endpoints:
- `/health/live` - Liveness probe (checks if application is running)
- `/health/ready` - Readiness probe (checks if application is ready to serve traffic)

#### Document Processing (Optional)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `documentProcessing.enabled` | Enable document processing | `false` |
| `documentProcessing.defaultProcessor` | Default processor | `unstructured` |
| `documentProcessing.unstructured.enabled` | Enable Unstructured.io processor | `false` |
| `documentProcessing.unstructured.apiUrl` | Unstructured API URL | `http://unstructured:8000` |
| `documentProcessing.tesseract.enabled` | Enable Tesseract OCR | `false` |

#### Webhooks (Optional)

Nextcloud can push change events to the MCP server so vector sync reacts in near real-time instead of waiting for the next polling scan. As of app version **0.117.2** a webhook secret is **required** to enable webhooks ([GHSA-8vh3-g2qg-2h2c](https://github.com/cbcoutinho/nextcloud-mcp-server/security/advisories/GHSA-8vh3-g2qg-2h2c)).

When a webhook secret is configured the server mounts the `/webhooks/nextcloud` receiver, registers webhooks with Nextcloud using `Authorization: Bearer <secret>`, and validates that header on every delivery. When **unset** the receiver route is not mounted, the receiver refuses requests (`503`), and registration is skipped — vector sync still works via the periodic polling scanner.

These env vars are injected only into the API pod; the ingest worker (`ingest.splitWorker: true`) drains the queue and never handles webhooks.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `webhooks.secret` | Inline webhook secret (`WEBHOOK_SECRET`). **Must be ≥16 characters.** Ignored if `existingSecret` is set | `""` |
| `webhooks.existingSecret` | Use an existing Secret holding the webhook secret instead of creating one | `""` |
| `webhooks.secretKey` | Key in the Secret that holds the webhook secret | `webhook-secret` |
| `webhooks.internalUrl` | Internal callback URL registered with Nextcloud (`WEBHOOK_INTERNAL_URL`); wins over `nextcloud.mcpServerUrl` and autodetection | `""` |

Generate a secret with e.g. `python -c "import secrets; print(secrets.token_urlsafe(32))"`.

#### Vector Search & Semantic Capabilities (Optional)

Enable semantic search capabilities with BM25 hybrid search by deploying a vector database (Qdrant) and embedding service (Ollama or OpenAI).

**Semantic Search Configuration:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `semanticSearch.enabled` | Enable semantic search and background vector synchronization | `false` |
| `semanticSearch.scanInterval` | Scan interval in seconds | `3600` |
| `semanticSearch.processorWorkers` | Number of concurrent processor workers | `3` |
| `semanticSearch.queueMaxSize` | Maximum queue size for pending documents | `10000` |
| `semanticSearch.excludedTags` | Comma-separated Nextcloud tag names to exclude from indexing (`EXCLUDED_TAGS`) | `""` |
| `semanticSearch.vectorTag` | Nextcloud tag marking files for hybrid (dense + BM25 sparse) indexing (`VECTOR_SYNC_TAG`) | `"vector-index"` |
| `semanticSearch.keywordTag` | Nextcloud tag marking files for keyword-only (BM25 sparse) indexing (`VECTOR_SYNC_KEYWORD_TAG`); set `""` to disable; hybrid wins when a file carries both | `"keyword-index"` |

**Ingest Queue Configuration (Deck #183):**

procrastinate is **opt-in**. By default document processing runs in-process via anyio task groups (`INGEST_QUEUE=memory`) — even with a PostgreSQL database backend. Set `ingest.splitWorker=true` to split ingest into a procrastinate Postgres queue (`INGEST_QUEUE=postgres`, `MCP_ROLE=api`) drained by a dedicated worker Deployment (`MCP_ROLE=worker`). Requires a PostgreSQL `database.url`/`database.existingSecret`.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingest.splitWorker` | Split ingest into a procrastinate queue + worker Deployment (opt-in; requires PostgreSQL). When `false`, processing stays in-process | `false` |
| `ingest.worker.replicaCount` | Worker replicas (a floor; a KEDA ScaledObject may manage scale-to-zero) | `1` |
| `ingest.worker.concurrency` | Max concurrent jobs per worker (empty → `VECTOR_SYNC_PROCESSOR_WORKERS`) | `""` |
| `ingest.worker.resources` | Worker resource requests/limits | `{}` |
| `ingest.worker.nodeSelector` | Worker node selector | `{}` |
| `ingest.worker.tolerations` | Worker tolerations | `[]` |
| `ingest.worker.affinity` | Worker affinity | `{}` |

**Document Chunking Configuration:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `documentChunking.chunkSize` | Number of words per chunk for embedding | `512` |
| `documentChunking.chunkOverlap` | Number of overlapping words between chunks | `50` |

**Chunking Strategy:**
- **Small chunks (256-384)**: Better precision for searches, more storage overhead
- **Medium chunks (512-768)**: Balanced approach (recommended for most use cases)
- **Large chunks (1024+)**: Better context preservation, less precise matching
- **Overlap**: Should be 10-20% of chunk size to preserve context across boundaries

**Qdrant Vector Database:**

Qdrant supports four deployment modes via `qdrant.mode`:

| Mode | Description | When to Use |
|------|-------------|-------------|
| `memory` | In-memory (`:memory:`), zero config | Development, small ephemeral workloads |
| `persistent` | Local file storage in `/app/data/qdrant` | Single-pod with persistent volume |
| `sidecar` | Qdrant runs as a sidecar container reachable on `localhost` | Single-pod with no external dependency, full Qdrant features |
| `network` | External Qdrant service or `qdrant/qdrant` subchart | Production, shared/scaled Qdrant |

**Sidecar mode** (`qdrant.mode: sidecar`) deploys the upstream `qdrant/qdrant` image alongside the MCP server container in the same pod. The MCP server connects via `localhost:6333`, and persistence piggybacks on `dataStorage` (set `dataStorage.enabled: true` for durability). The qdrant `/metrics` endpoint is exposed through the Service and ServiceMonitor automatically.

The `sidecar.image.tag` is tracked by Renovate; the `network` subchart's image is governed by the upstream qdrant Helm chart and is not overridden here.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `qdrant.mode` | Deployment mode (`memory`, `persistent`, `sidecar`, `network`) | `memory` |
| `qdrant.collection` | Collection name for vector data | `nextcloud_content` |
| `qdrant.sidecar.image.repository` | Sidecar image repository | `docker.io/qdrant/qdrant` |
| `qdrant.sidecar.image.tag` | Sidecar image tag (Renovate-managed) | `v1.17.1` |
| `qdrant.sidecar.apiKey` | Optional API key for sidecar (rarely needed) | `""` |
| `qdrant.sidecar.resources` | Resources for the sidecar container | See `values.yaml` |
| `qdrant.networkMode.deploySubchart` | Deploy `qdrant/qdrant` as a subchart | `false` |
| `qdrant.networkMode.externalUrl` | External Qdrant URL (when `deploySubchart: false`) | `""` |
| `qdrant.subchart.persistence.size` | Storage size when subchart is deployed | `10Gi` |
| `qdrant.subchart.resources` | Resources for the qdrant subchart | See `values.yaml` |

**Ollama Embedding Service:**

Ollama is deployed as a subchart when `ollama.enabled` is `true`. All configuration values are passed through to the [ollama/ollama](https://github.com/otwld/ollama-helm) chart. Alternatively, set `ollama.url` to use an external Ollama instance.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ollama.enabled` | Deploy Ollama as a subchart | `false` |
| `ollama.url` | External Ollama URL (use with `enabled: false`) | `""` |
| `ollama.embeddingModel` | Embedding model to use | `nomic-embed-text` |
| `ollama.verifySsl` | Verify SSL certificates | `true` |
| `ollama.replicaCount` | Number of Ollama replicas | `1` |
| `ollama.ollama.models.pull` | Models to pull on startup | `["nomic-embed-text"]` |
| `ollama.persistentVolume.enabled` | Enable persistent storage | `true` |
| `ollama.persistentVolume.size` | Storage size for models | `20Gi` |
| `ollama.resources.requests.cpu` | CPU request | `500m` |
| `ollama.resources.requests.memory` | Memory request | `1Gi` |
| `ollama.resources.limits.cpu` | CPU limit | `2000m` |
| `ollama.resources.limits.memory` | Memory limit | `4Gi` |

**OpenAI Embedding Provider (Alternative):**

Use OpenAI or any OpenAI-compatible API instead of Ollama.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `openai.enabled` | Enable OpenAI embedding provider | `false` |
| `openai.apiKey` | OpenAI API key | `""` |
| `openai.existingSecret` | Use existing secret for API key | `""` |
| `openai.secretKey` | Key in secret containing API key | `api-key` |
| `openai.baseUrl` | Custom API endpoint (optional) | `""` |

**Mistral Embedding Provider (Alternative):**

A first-class Mistral provider, distinct from the OpenAI-compatible path. `MISTRAL_API_KEY` alone enables it. Enabling this block also supplies the credentials used by the **Mistral-direct OCR backend** (see PDF Pipeline & OCR below).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mistral.enabled` | Enable Mistral embedding provider (and provide `MISTRAL_API_KEY` for Mistral-direct OCR) | `false` |
| `mistral.apiKey` | Mistral API key (ignored if `existingSecret` set) | `""` |
| `mistral.existingSecret` | Use existing secret for API key | `""` |
| `mistral.secretKey` | Key in secret containing API key | `api-key` |
| `mistral.embeddingModel` | Embedding model (1024-dim default) | `mistral-embed` |
| `mistral.baseUrl` | Custom API endpoint, e.g. `https://api.mistral.ai/v1` (`MISTRAL_BASE_URL`) | `""` |

#### PDF Pipeline & OCR (Optional)

A tiered PDF extraction pipeline runs on the **semantic-search / vector-ingestion path** (whenever `semanticSearch.enabled` is `true` and a PDF is indexed). It is **separate from** the legacy `documentProcessing` block above — enabling OCR here does **not** require `documentProcessing.enabled`.

PDFs are extracted with a fast tier (`pypdfium2`); scanned / no-text-layer PDFs can optionally be escalated to **tier-3 OCR**. OCR has two interchangeable backends, selected by `documentPipeline.ocr.provider`:

- **`mistral`** — calls the Mistral OCR API directly from the pod. Enable the `mistral` block so `MISTRAL_API_KEY` is present. Works for any self-hoster.
- **`gateway`** — routes OCR through a model gateway (no provider keys in the pod). The gateway URL + M2M credentials (`EMBEDDING_GATEWAY_URL` / `_TOKEN_URL` / `_CLIENT_ID` / `_CLIENT_SECRET` / `_SCOPE`) are **intentionally not part of this chart**; supply them from your own overlay via `extraEnv` (see below).
- **`auto`** — prefer the gateway if `EMBEDDING_GATEWAY_URL` is set, else Mistral if `MISTRAL_API_KEY` is set, else OCR stays disabled.

OCR backend selection is independent of the embedding provider — you can embed via Ollama/OpenAI and OCR via Mistral/gateway.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `documentPipeline.tier1Engine` | Fast-tier PDF engine: `pypdfium2` (default) or `pymupdf` (deprecated rollback) | `pypdfium2` |
| `documentPipeline.classifyEnabled` | Record tier-0 classification metrics | `true` |
| `documentPipeline.glyphCorruptionRatio` | Doc-level C0-control-char ratio above which a glyph-corrupt (broken `/ToUnicode`) text layer escalates `fast`→`structured` (pymupdf); `0` disables | `0.02` |
| `documentPipeline.parseTimeoutSeconds` | Per-PDF parse timeout (seconds) | `120` |
| `documentPipeline.parseMemLimitMb` | RLIMIT_AS memory cap for the parse subprocess (MB) | `1536` |
| `documentPipeline.parsePageWindow` | Pages per pypdfium2 extraction window; bounds peak RSS on page-heavy PDFs; `0` disables windowing | `100` |
| `documentPipeline.parseProcessSlots` | Max concurrent isolated parse subprocesses (otherwise `os.cpu_count()`) | `2` |
| `documentPipeline.pdfGraphicsLimit` | Max vector graphics per PDF before bailing (pymupdf path) | `1000` |
| `documentPipeline.maxPdfSizeMb` | Pre-parse size cap (MB); larger PDFs fail fast (`oversize`) instead of burning the timeout; `0` disables | `50` |
| `documentPipeline.ocr.enabled` | Enable tier-3 OCR for scanned PDFs | `false` |
| `documentPipeline.ocr.provider` | OCR backend: `auto`, `gateway`, `mistral`, `none` | `auto` |
| `documentPipeline.ocr.model` | Provider-namespaced OCR model id | `mistral/mistral-ocr-latest` |
| `documentPipeline.ocr.timeoutSeconds` | OCR backend request timeout (seconds) | `180` |
| `documentPipeline.ocr.mode` | OCR execution mode: `sync` (inline) or `batch` (async gateway Batch OCR; **requires a gateway**) | `sync` |
| `documentPipeline.ocr.batchPollSeconds` | Batch mode only: seconds between batch-job polls | `120` |
| `documentPipeline.ocr.batchMaxWaitSeconds` | Batch mode only: hard deadline (seconds from submit) before a pending batch job is abandoned | `86400` |
| `documentPipeline.ocr.minTextQuality` | Escalation: text-quality score `[0,1]` below which a page is junk and OCR-worthy | `0.5` |
| `documentPipeline.ocr.pageFraction` | Escalation: fraction of sampled pages `[0,1]` that must be OCR-worthy before the whole doc escalates | `0.5` |
| `documentPipeline.ocr.minPageChars` | Escalation: a page with fewer extracted chars than this counts as near-empty | `16` |
| `documentPipeline.ocr.detectScanned` | Escalation: run raster-image analysis to detect scanned pages (OCR-enabled only) | `true` |

**Enable OCR via Mistral directly:**

```yaml
semanticSearch:
  enabled: true
documentPipeline:
  ocr:
    enabled: true
    provider: mistral
mistral:
  enabled: true
  existingSecret: mistral-api-key   # or set mistral.apiKey
```

**Enable OCR via a model gateway** (gateway connection details supplied by your own overlay, keeping them out of the public chart values):

```yaml
semanticSearch:
  enabled: true
documentPipeline:
  ocr:
    enabled: true
    provider: gateway
# Gateway URL + M2M creds injected via extraEnv (not chart-native):
extraEnv:
  - name: EMBEDDING_GATEWAY_URL
    value: "https://<gateway-host>"
  - name: EMBEDDING_GATEWAY_TOKEN_URL
    value: "https://<idp>/.../token"
  - name: EMBEDDING_GATEWAY_SCOPE
    value: "<gateway>/embed"
  - name: EMBEDDING_GATEWAY_CLIENT_ID
    valueFrom:
      secretKeyRef: { name: gateway-creds, key: client_id }
  - name: EMBEDDING_GATEWAY_CLIENT_SECRET
    valueFrom:
      secretKeyRef: { name: gateway-creds, key: client_secret }
```

#### Observability & Monitoring

The chart includes comprehensive observability features including Prometheus metrics, OpenTelemetry tracing, and Grafana dashboards.

**Metrics Configuration:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observability.metrics.enabled` | Enable Prometheus metrics | `true` |
| `observability.metrics.port` | Metrics port | `9090` |
| `observability.metrics.path` | Metrics endpoint path | `/metrics` |

**Tracing Configuration:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observability.tracing.enabled` | Enable OpenTelemetry tracing | `false` |
| `observability.tracing.endpoint` | OTLP collector endpoint | `""` |
| `observability.tracing.serviceName` | Service name in traces | `nextcloud-mcp-server` |
| `observability.tracing.samplingRate` | Trace sampling rate (0.0-1.0); passed as the sampler arg (`OTEL_TRACES_SAMPLER_ARG`) | `1.0` |
| `observability.tracing.sampler` | OTEL sampler strategy (`OTEL_TRACES_SAMPLER`): `always_on`, `always_off`, `traceidratio`, `parentbased_*` | `always_on` |
| `observability.tracing.verifySsl` | Verify TLS to the OTLP endpoint (`OTEL_EXPORTER_VERIFY_SSL`) | `false` |

**Profiling Configuration (Pyroscope, requires appVersion ≥ 0.137.0):**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observability.profiling.enabled` | Enable continuous profiling; pushes CPU/wall profiles to `serverAddress` (`PYROSCOPE_ENABLED`) | `false` |
| `observability.profiling.serverAddress` | Pyroscope-compatible ingest endpoint, e.g. Grafana Alloy's `pyroscope.receive_http` (`PYROSCOPE_SERVER_ADDRESS`) | `""` |

**Logging Configuration:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observability.logging.format` | Log format (json or text) | `json` |
| `observability.logging.level` | Log level | `INFO` |
| `observability.logging.includeTraceContext` | Include trace IDs in logs | `true` |

**ServiceMonitor (Prometheus Operator):**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Create ServiceMonitor resource | `false` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |
| `serviceMonitor.labels` | Additional labels for ServiceMonitor | `{}` |

**PrometheusRule (Prometheus Operator):**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `prometheusRule.enabled` | Create PrometheusRule with alert rules | `false` |
| `prometheusRule.labels` | Additional labels for PrometheusRule | `{}` |

**Grafana Dashboards:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dashboards.enabled` | Enable automatic dashboard provisioning | `false` |
| `dashboards.grafanaFolder` | Grafana folder name for dashboards | `Nextcloud MCP` |
| `dashboards.labels` | Additional labels for dashboard ConfigMap | `{}` |
| `dashboards.annotations` | Additional annotations for dashboard ConfigMap | `{}` |

When `dashboards.enabled` is `true`, a ConfigMap with the Grafana dashboard is created with the `grafana_dashboard: "1"` label. This enables automatic discovery by Grafana sidecar containers (commonly used with kube-prometheus-stack).

The dashboard provides comprehensive monitoring including:
- HTTP request metrics (RED pattern: Rate, Errors, Duration)
- MCP tool performance and errors
- Nextcloud API performance by app (notes, calendar, contacts, etc.)
- OAuth token operations and cache hit rates
- External dependency health (Nextcloud, Qdrant, Keycloak, Unstructured API)
- Vector sync processing pipeline (when enabled)

For manual import or more details, see `charts/nextcloud-mcp-server/dashboards/README.md`.

## Examples

### Example 1: Basic Auth with Ingress

```yaml
nextcloud:
  host: https://cloud.example.com

auth:
  mode: basic
  basic:
    username: admin
    password: secure-password

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: mcp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mcp-tls
      hosts:
        - mcp.example.com

resources:
  limits:
    cpu: 2000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
```

### Example 2: Using Existing Secrets

#### Basic Auth with Existing Secret

Create a secret manually:

```bash
kubectl create secret generic nextcloud-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypassword
```

Then reference it in your values:

```yaml
nextcloud:
  host: https://cloud.example.com

auth:
  mode: basic
  basic:
    existingSecret: nextcloud-credentials
    usernameKey: username
    passwordKey: password
```

#### OAuth with Existing Secret (Pre-registered Client)

If you have a pre-registered OAuth client:

```bash
kubectl create secret generic nextcloud-oauth-creds \
  --from-literal=clientId=my-oauth-client-id \
  --from-literal=clientSecret=my-oauth-client-secret
```

Then reference it in your values:

```yaml
nextcloud:
  host: https://cloud.example.com
  # mcpServerUrl and publicIssuerUrl are optional!
  # If not set, mcpServerUrl defaults to ingress host or localhost
  # publicIssuerUrl defaults to nextcloud.host (only used for browser-accessible auth endpoint)

auth:
  mode: oauth
  oauth:
    existingSecret: nextcloud-oauth-creds
    clientIdKey: clientId
    clientSecretKey: clientSecret
    persistence:
      enabled: true

ingress:
  enabled: true
  hosts:
    - host: mcp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mcp-tls
      hosts:
        - mcp.example.com
```

### Example 3: OAuth with Document Processing and Dynamic Client Registration

This example shows OAuth without pre-registered credentials (using DCR) and optional URL values:

```yaml
nextcloud:
  host: https://cloud.example.com
  # mcpServerUrl will automatically use ingress host (https://mcp.example.com)
  # publicIssuerUrl will automatically default to nextcloud.host (only used for browser-accessible auth endpoint)

auth:
  mode: oauth
  oauth:
    # No clientId/clientSecret - will use Dynamic Client Registration!
    persistence:
      enabled: true
      storageClass: fast-ssd
      size: 200Mi

documentProcessing:
  enabled: true
  defaultProcessor: unstructured
  unstructured:
    enabled: true
    apiUrl: http://unstructured-api:8000
    strategy: hi_res
    languages: eng,deu,fra

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: mcp.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Example 4: High Availability with Autoscaling

```yaml
replicaCount: 2

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

resources:
  limits:
    cpu: 2000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - nextcloud-mcp-server
          topologyKey: kubernetes.io/hostname
```

### Example 5: Semantic Search with Qdrant and Ollama

Deploy with vector search capabilities using embedded Qdrant and Ollama:

```yaml
nextcloud:
  host: https://cloud.example.com

auth:
  mode: basic
  basic:
    username: admin
    password: secure-password

# Enable semantic search
semanticSearch:
  enabled: true
  scanInterval: 1800  # Scan every 30 minutes
  processorWorkers: 5

# Deploy Qdrant as a subchart
qdrant:
  enabled: true
  persistence:
    size: 20Gi
    storageClass: fast-ssd
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

# Deploy Ollama as a subchart
ollama:
  enabled: true
  embeddingModel: nomic-embed-text
  persistentVolume:
    size: 30Gi
    storageClass: standard
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

Or use an external Ollama instance:

```yaml
semanticSearch:
  enabled: true

qdrant:
  enabled: true

# Use external Ollama instead of deploying subchart
ollama:
  enabled: false
  url: "http://ollama.ai-services.svc.cluster.local:11434"
  embeddingModel: nomic-embed-text
```

Or use OpenAI for embeddings:

```yaml
semanticSearch:
  enabled: true

qdrant:
  enabled: true

# Use OpenAI instead of Ollama
openai:
  enabled: true
  apiKey: "sk-..."
  # Or use existing secret:
  # existingSecret: openai-api-key
  # secretKey: api-key
```

## Upgrading

### To upgrade an existing deployment:

```bash
# Update the repository
helm repo update

# Upgrade with your custom values
helm upgrade nextcloud-mcp nextcloud-mcp/nextcloud-mcp-server -f custom-values.yaml
```

### To upgrade with new values:

```bash
helm upgrade nextcloud-mcp nextcloud-mcp/nextcloud-mcp-server \
  --set resources.limits.memory=1Gi
```

## Uninstalling

```bash
helm uninstall nextcloud-mcp
```

**Note:** This will delete all resources including PVCs. If you want to preserve OAuth client data, backup the PVC before uninstalling.

## Troubleshooting

### Check pod status

```bash
kubectl get pods -l app.kubernetes.io/name=nextcloud-mcp-server
```

### View logs

```bash
kubectl logs -l app.kubernetes.io/name=nextcloud-mcp-server --tail=100 -f
```

### Check health endpoints

The application exposes health check endpoints for monitoring:

```bash
# Port forward to the service
kubectl port-forward svc/nextcloud-mcp 8000:8000

# Check liveness (if app is running)
curl http://localhost:8000/health/live

# Check readiness (if app is ready to serve traffic)
curl http://localhost:8000/health/ready
```

**Example responses:**

Liveness (always returns 200 if running):
```json
{
  "status": "alive",
  "mode": "basic"
}
```

Readiness (returns 200 if ready, 503 if not ready):
```json
{
  "status": "ready",
  "checks": {
    "nextcloud_configured": "ok",
    "auth_mode": "basic",
    "auth_configured": "ok"
  }
}
```

### Common Issues

1. **Connection refused to Nextcloud**
   - Verify `nextcloud.host` is accessible from the Kubernetes cluster
   - For OAuth mode: Ensure MCP server can reach OIDC discovery endpoints (token, JWKS, introspection, userinfo URLs)
   - Check network policies and firewall rules
   - Note: Do not use internal Docker hostnames (like `http://app:80`) for `nextcloud.host` - use externally resolvable URLs

2. **Authentication failures**
   - For basic auth: verify username/password are correct
   - For OAuth: check that OIDC app is properly configured

3. **OAuth persistence issues**
   - Verify PVC is bound: `kubectl get pvc`
   - Check storage class exists: `kubectl get storageclass`

4. **Resource constraints**
   - Increase memory limits if seeing OOM errors
   - Adjust CPU requests based on load

## Security Considerations

1. **Secrets Management**: Consider using external secret management (e.g., Sealed Secrets, External Secrets Operator)
2. **TLS**: Always use TLS/HTTPS for production deployments
3. **Network Policies**: Restrict network access to necessary services only
4. **RBAC**: Review and customize ServiceAccount permissions as needed
5. **App Passwords**: For basic auth, use Nextcloud app passwords instead of main account passwords

## Support

- GitHub Issues: https://github.com/cbcoutinho/nextcloud-mcp-server/issues
- Documentation: https://github.com/cbcoutinho/nextcloud-mcp-server#readme

## License

This chart is licensed under AGPL-3.0, consistent with the Nextcloud MCP Server project.
