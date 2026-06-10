# find-api-calls.ps1 - Search decompiled Android output for network APIs and endpoint clues.
param(
    [Parameter(Position=0)]
    [string]$SourceDir,
    [switch]$Retrofit,
    [switch]$OkHttp,
    [switch]$Volley,
    [switch]$Urls,
    [switch]$Auth,
    [switch]$GraphQL,
    [switch]$WebSocket,
    [switch]$Grpc,
    [switch]$Security,
    [switch]$Resources,
    [string[]]$Focus,
    [switch]$ShowCommonNoise,
    [switch]$All,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host @"
Usage: find-api-calls.ps1 <source-or-output-dir> [OPTIONS]

Search decompiled Android source/resources for HTTP APIs, endpoint strings,
network client setup, authentication, and transport/security configuration.

Options:
  -Retrofit       Search only for Retrofit annotations
  -OkHttp         Search only for OkHttp patterns
  -Volley         Search only for Volley patterns
  -Urls           Search only for hardcoded URLs and URL construction
  -Auth           Search only for auth, headers, and base URL constants
  -GraphQL        Search only for GraphQL/Apollo patterns
  -WebSocket      Search only for WebSocket/SSE patterns
  -Grpc           Search only for gRPC patterns
  -Security       Search only for pinning and network security config
  -Resources      Search only for URLs/config in resource/build files
  -Focus PREFIX   Restrict source-code matches to package/path prefix; repeatable
                  Example: -Focus com.hhc -Focus com.thunderstone
  -ShowCommonNoise
                  Include common XML namespace/license/documentation URLs
  -All            Search all patterns (default)
  -Help           Show this help message
"@
    exit 0
}

if ($Help) { Show-Usage }

if (-not $SourceDir) {
    Write-Host "Error: No source directory specified." -ForegroundColor Red
    Show-Usage
}

if (-not (Test-Path $SourceDir)) {
    Write-Host "Error: Directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

$searchAll = (-not $Retrofit -and -not $OkHttp -and -not $Volley -and -not $Urls -and -not $Auth -and -not $GraphQL -and -not $WebSocket -and -not $Grpc -and -not $Security -and -not $Resources) -or $All

$CodeIncludes = @('*.java', '*.kt')
$TextIncludes = @('*.java', '*.kt', '*.xml', '*.json', '*.properties', '*.gradle', '*.graphql', '*.gql', '*.js', '*.ts')
$ResourceIncludes = @('*.xml', '*.json', '*.properties', '*.gradle')

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ===="
    Write-Host ""
}

function Search-Files {
    param(
        [string]$Pattern,
        [string]$Scope = 'Text',
        [switch]$IgnoreCase
    )

    $includes = switch ($Scope) {
        'Code' { $CodeIncludes }
        'Resources' { $ResourceIncludes }
        default { $TextIncludes }
    }

    $options = if ($IgnoreCase) {
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    } else {
        [System.Text.RegularExpressions.RegexOptions]::None
    }

    $focusPaths = @()
    if ($Focus) {
        $focusPaths = $Focus | ForEach-Object { $_.Replace('.', [System.IO.Path]::DirectorySeparatorChar) }
    }

    Get-ChildItem -Path $SourceDir -Recurse -Include $includes -File |
        ForEach-Object {
            $path = $_.FullName
            if ($focusPaths.Count -gt 0 -and $path -like "*$([System.IO.Path]::DirectorySeparatorChar)sources$([System.IO.Path]::DirectorySeparatorChar)*") {
                $matched = $false
                foreach ($focusPath in $focusPaths) {
                    if ($path -like "*$([System.IO.Path]::DirectorySeparatorChar)sources$([System.IO.Path]::DirectorySeparatorChar)$focusPath$([System.IO.Path]::DirectorySeparatorChar)*") {
                        $matched = $true
                        break
                    }
                }
                if (-not $matched) { return }
            }
            $lineNumber = 0
            Get-Content -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                $lineNumber += 1
                if ([regex]::IsMatch($_, $Pattern, $options)) {
                    $line = "${path}:${lineNumber}:$($_.Trim())"
                    if ($ShowCommonNoise -or -not ([regex]::IsMatch($line, '(/R\.java:|schemas\.android\.com|www\.w3\.org|apache\.org/licenses|opensource\.org/licenses|www\.slf4j\.org|xmlpull\.org|java\.sun\.com|developer\.android\.com/reference|google\.com/schemas|maven\.apache\.org)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))) {
                        $line
                    }
                }
            }
        }
}

if ($searchAll -or $Retrofit) {
    Write-Section "Retrofit Annotations"
    Search-Files '@(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|HTTP)\s*\(' -Scope Code
    Write-Section "Retrofit Headers & Parameters"
    Search-Files '@(Headers|Header|HeaderMap|Query|QueryMap|Path|Body|Field|FieldMap|Part|PartMap|Url)\s*\(' -Scope Code
    Write-Section "Retrofit Base URL / Service Creation"
    Search-Files '(Retrofit\.Builder|\.baseUrl\s*\(|Retrofit[^;]*\.create\s*\(|retrofit[^;]*\.create\s*\(|retrofit2\.)' -Scope Code
}

if ($searchAll -or $OkHttp) {
    Write-Section "OkHttp Request Building"
    Search-Files '(Request\.Builder|OkHttpClient|\.newCall\s*\(|\.enqueue\s*\(|\.execute\s*\(|\.method\s*\()' -Scope Code
    Write-Section "OkHttp URL / Header Construction"
    Search-Files '(\.url\s*\(|HttpUrl|\.addQueryParameter|\.addPathSegment|\.scheme\s*\(|\.host\s*\(|\.addHeader\s*\(|\.header\s*\()' -Scope Code
    Write-Section "OkHttp Interceptors"
    Search-Files '(Interceptor|addInterceptor|addNetworkInterceptor|intercept\s*\(|chain\.request|chain\.proceed)' -Scope Code
}

if ($searchAll -or $Volley) {
    Write-Section "Volley Requests"
    Search-Files '(StringRequest|JsonObjectRequest|JsonArrayRequest|ImageRequest|RequestQueue|Volley\.newRequestQueue|com\.android\.volley)' -Scope Code
}

if ($searchAll -or $Urls) {
    Write-Section "Hardcoded URLs"
    Search-Files '"(https?|wss?)://[^"]+' -Scope Text
    Write-Section "HttpURLConnection"
    Search-Files '(openConnection|setRequestMethod|setRequestProperty|HttpURLConnection|HttpsURLConnection)' -Scope Code
    Write-Section "WebView URLs"
    Search-Files '(\.loadUrl\s*\(|\.loadData\s*\(|\.evaluateJavascript\s*\(|\.addJavascriptInterface\s*\(|WebViewClient|WebChromeClient|shouldOverrideUrlLoading)' -Scope Code
    Write-Section "Dynamic Endpoint Construction"
    Search-Files '(Uri\.Builder|URL\s*\(|URI\s*\(|StringBuilder|appendPath|appendQueryParameter|encodedPath|pathSegments)' -Scope Code
}

if ($searchAll -or $Auth) {
    Write-Section "Authentication & API Keys"
    Search-Files '(api[_-]?key|auth[_-]?token|bearer|authorization|x-api-key|client[_-]?secret|access[_-]?token|refresh[_-]?token|jwt|oauth|basic auth)' -Scope Text -IgnoreCase
    Write-Section "Base URLs and Constants"
    Search-Files '(BASE_URL|API_URL|SERVER_URL|ENDPOINT|API_BASE|HOST_NAME|HOST_URL|GRAPHQL_URL|SOCKET_URL|WEBSOCKET_URL)' -Scope Text -IgnoreCase
    Write-Section "Header Construction"
    Search-Files '(\.addHeader\s*\(|\.header\s*\(|setRequestProperty\s*\(|@Headers\s*\(|@Header\s*\()' -Scope Code
}

if ($searchAll -or $GraphQL) {
    Write-Section "GraphQL / Apollo"
    Search-Files '(ApolloClient|apollo3|apollo-runtime|GraphQL|graphql|\.graphql|\.gql|query\s+[A-Za-z_][A-Za-z0-9_]*|mutation\s+[A-Za-z_][A-Za-z0-9_]*|subscription\s+[A-Za-z_][A-Za-z0-9_]*)' -Scope Text -IgnoreCase
}

if ($searchAll -or $WebSocket) {
    Write-Section "WebSocket"
    Search-Files '(wss?://|WebSocket|newWebSocket|WebSocketListener|Socket\.IO|socketio|EventSource|text/event-stream|ServerSentEvent)' -Scope Text -IgnoreCase
}

if ($searchAll -or $Grpc) {
    Write-Section "gRPC"
    Search-Files '(ManagedChannel|ManagedChannelBuilder|io\.grpc|grpc|newBlockingStub|newFutureStub|newStub|forAddress\s*\(|useTransportSecurity)' -Scope Text -IgnoreCase
}

if ($searchAll -or $Security) {
    Write-Section "Certificate Pinning & Network Security"
    Search-Files '(CertificatePinner|certificate pin|sha256/|pin-set|network-security-config|network_security_config|cleartextTrafficPermitted|TrustManager|X509TrustManager|HostnameVerifier|checkServerTrusted|SSLSocketFactory)' -Scope Text -IgnoreCase
}

if ($searchAll -or $Resources) {
    Write-Section "Resource URLs"
    Search-Files '(https?|wss?)://[^"<\s]+' -Scope Resources -IgnoreCase
    Write-Section "Build-Time Network Config"
    Search-Files '(buildConfigField|resValue|manifestPlaceholders|BASE_URL|API_URL|SERVER_URL|ENDPOINT|google-services|firebase)' -Scope Text -IgnoreCase
}

Write-Host ""
Write-Host "=== Search complete ==="
