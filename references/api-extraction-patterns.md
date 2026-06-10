# API Extraction Patterns

Patterns and grep commands for finding HTTP API calls in decompiled Android source code.

## Retrofit

Retrofit is the most common HTTP client in Android apps. API endpoints are declared as annotated interface methods.

### Annotations to search for

```bash
# HTTP method annotations
grep -rn '@GET\|@POST\|@PUT\|@DELETE\|@PATCH\|@HEAD' sources/

# Parameter annotations
grep -rn '@Query\|@QueryMap\|@Path\|@Body\|@Field\|@FieldMap\|@Part\|@Header\|@HeaderMap' sources/

# Headers annotation (static headers)
grep -rn '@Headers' sources/

# Base URL configuration
grep -rn 'baseUrl\|\.baseUrl(' sources/
```

### Typical Retrofit interface

```java
public interface ApiService {
    @GET("users/{id}")
    Call<User> getUser(@Path("id") String userId);

    @POST("auth/login")
    @Headers({"Content-Type: application/json"})
    Call<LoginResponse> login(@Body LoginRequest request);
}
```

When documenting, capture: HTTP method, path, path parameters, query parameters, request body type, response type, and any static headers.

## OkHttp

OkHttp is often used directly or as the transport layer for Retrofit.

```bash
# Request building
grep -rn 'Request\.Builder\|Request.Builder\|\.url(\|\.post(\|\.put(\|\.delete(\|\.patch(' sources/

# URL construction
grep -rn 'HttpUrl\|\.addQueryParameter\|\.addPathSegment' sources/

# Interceptors (often add auth headers)
grep -rn 'Interceptor\|addInterceptor\|addNetworkInterceptor\|intercept(' sources/

# Response handling
grep -rn '\.execute()\|\.enqueue(' sources/
```

## Volley

```bash
grep -rn 'StringRequest\|JsonObjectRequest\|JsonArrayRequest\|Volley\.newRequestQueue\|RequestQueue' sources/
```

Volley requests typically pass the URL as a constructor argument and override `getHeaders()` or `getParams()` for custom headers/parameters.

## HttpURLConnection (legacy)

```bash
grep -rn 'HttpURLConnection\|HttpsURLConnection\|openConnection\|setRequestMethod\|setRequestProperty' sources/
```

## WebView

```bash
grep -rn 'loadUrl\|evaluateJavascript\|addJavascriptInterface\|WebViewClient\|shouldOverrideUrlLoading' sources/
```

WebView-based apps may load API endpoints via JavaScript bridges. Look for `@JavascriptInterface` annotated methods.

## GraphQL / Apollo

GraphQL clients often expose one endpoint, then define operations in generated classes or `.graphql`/`.gql` files.

```bash
# Apollo client setup and GraphQL endpoint
grep -rni 'ApolloClient\|serverUrl\|graphql\|GraphQL' sources/ resources/

# Operation names and generated calls
grep -rni 'query \|mutation \|subscription \|\.graphql\|\.gql' sources/ resources/
```

When documenting GraphQL, capture the GraphQL server URL, operation name, operation type (`query`, `mutation`, `subscription`), variables, auth headers, and caller. Do not treat the GraphQL endpoint alone as complete API coverage; the operation body is the actual API shape.

## WebSocket / SSE

```bash
grep -rni 'wss://\|ws://\|WebSocket\|newWebSocket\|WebSocketListener\|EventSource\|text/event-stream' sources/ resources/
```

Document WebSocket/SSE channels with URL, connection headers/auth, message types, subscription payloads, reconnect behavior, and the caller that opens the stream.

## gRPC

```bash
grep -rni 'ManagedChannel\|ManagedChannelBuilder\|io\.grpc\|newBlockingStub\|newFutureStub\|newStub\|forAddress' sources/
```

For gRPC, capture host, port, TLS usage, generated service/stub class, method names, metadata/auth interceptors, and protobuf message types.

## Certificate Pinning and Network Security

```bash
grep -rni 'CertificatePinner\|sha256/\|pin-set\|network_security_config\|cleartextTrafficPermitted\|TrustManager\|HostnameVerifier' sources/ resources/
```

Certificate pinning and custom trust managers do not define APIs, but they affect reproducibility. Document them with the API host they protect and whether traffic can be intercepted without extra setup.

## Resource and Build-Time URLs

URLs and hosts often live outside Java/Kotlin code:

```bash
grep -rni 'https://\|http://\|wss://\|BASE_URL\|API_URL\|SERVER_URL\|ENDPOINT' resources/ sources/
grep -rni 'buildConfigField\|resValue\|manifestPlaceholders\|google-services\|firebase' .
```

Check `strings.xml`, `network_security_config.xml`, JSON/properties files, assets, generated `BuildConfig`, Gradle files, and environment-specific flavor files.

## Hardcoded URLs and Secrets

```bash
# HTTP/HTTPS URLs
grep -rn '"https\?://[^"]*"' sources/

# API keys and tokens
grep -rni 'api[_-]\?key\|api[_-]\?secret\|auth[_-]\?token\|bearer\|access[_-]\?token\|client[_-]\?secret' sources/

# Base URL constants
grep -rni 'BASE_URL\|API_URL\|SERVER_URL\|ENDPOINT\|API_BASE' sources/
```

## Documentation Template

For each discovered API endpoint, document it using this template:

```markdown
### `METHOD /path/to/endpoint`

- **Source**: `com.example.app.api.ApiService` (file:line)
- **Base URL**: `https://api.example.com/v1`
- **Full URL**: `https://api.example.com/v1/path/to/endpoint`
- **Path parameters**: `id` (String)
- **Query parameters**: `page` (int), `limit` (int)
- **Headers**:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **Request body**: `LoginRequest { email: String, password: String }`
- **Response type**: `ApiResponse<User>`
- **Notes**: Called from `LoginActivity.onLoginClicked()`
```

## Search Strategy

1. Start with **base URL constants** — find where the API root is configured
2. Identify **app-owned package prefixes** from `AndroidManifest.xml` and top-level source paths, then use `--focus <prefix>` to avoid third-party library noise
3. Search for **resource/build-time URLs** — strings and flavors often hold hosts
4. Search for **Retrofit interfaces** — they give the clearest picture of REST endpoints
5. Check **OkHttp clients and interceptors** — they reveal auth schemes and common headers
6. Search for **GraphQL, WebSocket, and gRPC** — modern apps may not expose REST paths
7. Search for **hardcoded URLs** — catch one-off calls outside the main client
8. Check **network security and pinning** — record reproducibility constraints
9. Look for **WebView URLs and JavaScript bridges** — hybrid apps may call APIs outside native clients

For large APKs, run broad scan once, then focused scans:

```bash
bash scripts/find-api-calls.sh app-decompiled/
bash scripts/find-api-calls.sh app-decompiled/ --focus com.example.app --focus com.example.sdk
```
