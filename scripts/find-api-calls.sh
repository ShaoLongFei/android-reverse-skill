#!/usr/bin/env bash
# find-api-calls.sh - Search decompiled Android output for network APIs and endpoint clues.
set -euo pipefail

usage() {
  cat <<EOF
Usage: find-api-calls.sh <source-or-output-dir> [OPTIONS]

Search decompiled Android source/resources for HTTP APIs, endpoint strings,
network client setup, authentication, and transport/security configuration.

Arguments:
  <source-or-output-dir>  Decompiled sources directory or a full decompiled output root

Options:
  --retrofit      Search only for Retrofit annotations and parameters
  --okhttp        Search only for OkHttp patterns
  --volley        Search only for Volley patterns
  --urls          Search only for hardcoded URL strings and URL construction
  --auth          Search only for auth, API keys, headers, and base URL constants
  --graphql       Search only for GraphQL/Apollo patterns
  --websocket     Search only for WebSocket/SSE patterns
  --grpc          Search only for gRPC patterns
  --security      Search only for certificate pinning and network security config
  --resources     Search only for URLs/config in XML, JSON, properties, and Gradle files
  --focus PREFIX  Restrict source-code matches to package/path prefix; repeatable
                  Example: --focus com.hhc --focus com.thunderstone
  --show-common-noise
                  Include common XML namespace/license/documentation URLs
  --all           Search all patterns (default)
  -h, --help      Show this help message

Output:
  Results are printed as file:line:match for easy navigation.
EOF
  exit 0
}

SOURCE_DIR=""
SEARCH_RETROFIT=false
SEARCH_OKHTTP=false
SEARCH_VOLLEY=false
SEARCH_URLS=false
SEARCH_AUTH=false
SEARCH_GRAPHQL=false
SEARCH_WEBSOCKET=false
SEARCH_GRPC=false
SEARCH_SECURITY=false
SEARCH_RESOURCES=false
SEARCH_ALL=true
FOCUS_PATHS=()
SHOW_COMMON_NOISE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --retrofit)  SEARCH_RETROFIT=true; SEARCH_ALL=false; shift ;;
    --okhttp)    SEARCH_OKHTTP=true;   SEARCH_ALL=false; shift ;;
    --volley)    SEARCH_VOLLEY=true;   SEARCH_ALL=false; shift ;;
    --urls)      SEARCH_URLS=true;     SEARCH_ALL=false; shift ;;
    --auth)      SEARCH_AUTH=true;     SEARCH_ALL=false; shift ;;
    --graphql)   SEARCH_GRAPHQL=true;  SEARCH_ALL=false; shift ;;
    --websocket) SEARCH_WEBSOCKET=true; SEARCH_ALL=false; shift ;;
    --grpc)      SEARCH_GRPC=true;     SEARCH_ALL=false; shift ;;
    --security)  SEARCH_SECURITY=true; SEARCH_ALL=false; shift ;;
    --resources) SEARCH_RESOURCES=true; SEARCH_ALL=false; shift ;;
    --focus)
      if [[ $# -lt 2 ]]; then
        echo "Error: --focus requires a package prefix" >&2
        exit 1
      fi
      FOCUS_PATHS+=("${2//.//}")
      shift 2
      ;;
    --show-common-noise) SHOW_COMMON_NOISE=true; shift ;;
    --all)       SEARCH_ALL=true; shift ;;
    -h|--help)   usage ;;
    -*)          echo "Error: Unknown option $1" >&2; usage ;;
    *)           SOURCE_DIR="$1"; shift ;;
  esac
done

if [[ -z "$SOURCE_DIR" ]]; then
  echo "Error: No source directory specified." >&2
  usage
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: Directory not found: $SOURCE_DIR" >&2
  exit 1
fi

CODE_INCLUDES=(
  --include='*.java'
  --include='*.kt'
)

TEXT_INCLUDES=(
  --include='*.java'
  --include='*.kt'
  --include='*.xml'
  --include='*.json'
  --include='*.properties'
  --include='*.gradle'
  --include='*.graphql'
  --include='*.gql'
  --include='*.js'
  --include='*.ts'
)

RESOURCE_INCLUDES=(
  --include='*.xml'
  --include='*.json'
  --include='*.properties'
  --include='*.gradle'
)

section() {
  echo
  echo "==== $1 ===="
  echo
}

run_grep() {
  local scope="$1"
  local pattern="$2"
  local ignore_case="${3:-false}"
  local opts=(-RInE)

  case "$scope" in
    code) opts+=("${CODE_INCLUDES[@]}") ;;
    resources) opts+=("${RESOURCE_INCLUDES[@]}") ;;
    text) opts+=("${TEXT_INCLUDES[@]}") ;;
    *) echo "Internal error: unknown grep scope '$scope'" >&2; exit 1 ;;
  esac

  if [[ "$ignore_case" == true ]]; then
    opts=(-RInEi)
    case "$scope" in
      code) opts+=("${CODE_INCLUDES[@]}") ;;
      resources) opts+=("${RESOURCE_INCLUDES[@]}") ;;
      text) opts+=("${TEXT_INCLUDES[@]}") ;;
    esac
  fi

  grep "${opts[@]}" -- "$pattern" "$SOURCE_DIR" 2>/dev/null | filter_focus | filter_common_noise || true
}

filter_focus() {
  local line path focus

  if [[ ${#FOCUS_PATHS[@]} -eq 0 ]]; then
    cat
    return
  fi

  while IFS= read -r line; do
    path="${line%%:*}"

    # Resource/build files are not package-shaped; always keep them.
    if [[ "$path" == *"/resources/"* || "$path" != *"/sources/"* ]]; then
      echo "$line"
      continue
    fi

    for focus in "${FOCUS_PATHS[@]}"; do
      if [[ "$path" == *"/sources/$focus/"* ]]; then
        echo "$line"
        break
      fi
    done
  done
}

filter_common_noise() {
  if [[ "$SHOW_COMMON_NOISE" == true ]]; then
    cat
    return
  fi

  grep -Ev '(/R\.java:|schemas\.android\.com|www\.w3\.org|apache\.org/licenses|opensource\.org/licenses|www\.slf4j\.org|xmlpull\.org|java\.sun\.com|developer\.android\.com/reference|google\.com/schemas|maven\.apache\.org)' || true
}

# --- Retrofit ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_RETROFIT" == true ]]; then
  section "Retrofit Annotations"
  run_grep code '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\('
  section "Retrofit Headers & Parameters"
  run_grep code '@(Headers|Header|HeaderMap|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\('
  section "Retrofit Base URL / Service Creation"
  run_grep code '(Retrofit\.Builder|\.baseUrl\s*\(|Retrofit[^;]*\.create\s*\(|retrofit[^;]*\.create\s*\(|retrofit2\.)'
fi

# --- OkHttp ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_OKHTTP" == true ]]; then
  section "OkHttp Request Building"
  run_grep code '(Request\.Builder|OkHttpClient|\.newCall\s*\(|\.enqueue\s*\(|\.execute\s*\(|\.method\s*\()'
  section "OkHttp URL / Header Construction"
  run_grep code '(\.url\s*\(|HttpUrl|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\(|\.addHeader\s*\(|\.header\s*\()'
  section "OkHttp Interceptors"
  run_grep code '(Interceptor|addInterceptor|addNetworkInterceptor|intercept\s*\(|chain\.request|chain\.proceed)'
fi

# --- Volley ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_VOLLEY" == true ]]; then
  section "Volley Requests"
  run_grep code '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue|com\.android\.volley)'
fi

# --- Hardcoded URLs and URL construction ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_URLS" == true ]]; then
  section "Hardcoded URLs"
  run_grep text '"(https?|wss?)://[^"]+'
  section "HttpURLConnection"
  run_grep code '(openConnection|setRequestMethod|setRequestProperty|HttpURLConnection|HttpsURLConnection)'
  section "WebView URLs"
  run_grep code '(\.loadUrl\s*\(|\.loadData\s*\(|\.evaluateJavascript\s*\(|\.addJavascriptInterface\s*\(|WebViewClient|WebChromeClient|shouldOverrideUrlLoading)'
  section "Dynamic Endpoint Construction"
  run_grep code '(Uri\.Builder|URL\s*\(|URI\s*\(|StringBuilder|appendPath|appendQueryParameter|encodedPath|pathSegments)'
fi

# --- Authentication and constants ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_AUTH" == true ]]; then
  section "Authentication & API Keys"
  run_grep text '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token|refresh[_-]?token|jwt|oauth|basic auth)' true
  section "Base URLs and Constants"
  run_grep text '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME|HOST_URL|GRAPHQL_URL|SOCKET_URL|WEBSOCKET_URL)' true
  section "Header Construction"
  run_grep code '(\.addHeader\s*\(|\.header\s*\(|setRequestProperty\s*\(|@Headers\s*\(|@Header\s*\()'
fi

# --- GraphQL / Apollo ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_GRAPHQL" == true ]]; then
  section "GraphQL / Apollo"
  run_grep text '(ApolloClient|apollo3|apollo-runtime|GraphQL|graphql|\.graphql|\.gql|query\s+[A-Za-z_][A-Za-z0-9_]*|mutation\s+[A-Za-z_][A-Za-z0-9_]*|subscription\s+[A-Za-z_][A-Za-z0-9_]*)' true
fi

# --- WebSocket / SSE ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_WEBSOCKET" == true ]]; then
  section "WebSocket"
  run_grep text '(wss?://|WebSocket|newWebSocket|WebSocketListener|Socket\.IO|socketio|EventSource|text/event-stream|ServerSentEvent)' true
fi

# --- gRPC ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_GRPC" == true ]]; then
  section "gRPC"
  run_grep text '(ManagedChannel|ManagedChannelBuilder|io\.grpc|grpc|newBlockingStub|newFutureStub|newStub|forAddress\s*\(|useTransportSecurity)' true
fi

# --- Certificate pinning / Android network security ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_SECURITY" == true ]]; then
  section "Certificate Pinning & Network Security"
  run_grep text '(CertificatePinner|certificate pin|sha256/|pin-set|network-security-config|network_security_config|cleartextTrafficPermitted|TrustManager|X509TrustManager|HostnameVerifier|checkServerTrusted|SSLSocketFactory)' true
fi

# --- Resources and build-time config ---
if [[ "$SEARCH_ALL" == true || "$SEARCH_RESOURCES" == true ]]; then
  section "Resource URLs"
  run_grep resources '(https?|wss?)://[^"<[:space:]]+' true
  section "Build-Time Network Config"
  run_grep text '(buildConfigField|resValue|manifestPlaceholders|BASE_URL|API_URL|SERVER_URL|ENDPOINT|google-services|firebase)' true
fi

echo
echo "=== Search complete ==="
