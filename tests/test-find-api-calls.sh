#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/android-reverse-skill-test-XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/sources/com/example" \
  "$TMP_DIR/resources/res/xml" \
  "$TMP_DIR/resources/res/values"

cat > "$TMP_DIR/sources/com/example/ApiService.java" <<'JAVA'
package com.example;

import okhttp3.CertificatePinner;
import okhttp3.Request;
import retrofit2.http.GET;
import retrofit2.http.Header;

public interface ApiService {
    String BASE_URL = "https://api.example.com/v1/";

    @GET("users/{id}")
    Object user(@Header("Authorization") String token);

    default Request request() {
        return new Request.Builder()
            .url(BASE_URL + "events")
            .addHeader("X-API-Key", "demo")
            .build();
    }

    default CertificatePinner pinner() {
        return new CertificatePinner.Builder()
            .add("api.example.com", "sha256/abc")
            .build();
    }
}
JAVA

cat > "$TMP_DIR/sources/com/example/ModernClients.kt" <<'KOTLIN'
package com.example

import com.apollographql.apollo3.ApolloClient
import io.grpc.ManagedChannelBuilder
import okhttp3.WebSocketListener

class ModernClients : WebSocketListener() {
    val graph = ApolloClient.Builder()
        .serverUrl("https://api.example.com/graphql")
        .build()

    val channel = ManagedChannelBuilder
        .forAddress("grpc.example.com", 443)
        .useTransportSecurity()
        .build()

    val websocketUrl = "wss://stream.example.com/socket"
}
KOTLIN

cat > "$TMP_DIR/resources/res/xml/network_security_config.xml" <<'XML'
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set>
            <pin digest="SHA-256">abc</pin>
        </pin-set>
    </domain-config>
</network-security-config>
XML

cat > "$TMP_DIR/resources/res/values/strings.xml" <<'XML'
<resources>
    <string name="cdn_url">https://cdn.example.com/assets/</string>
</resources>
XML

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "Expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

auth_output="$(bash "$ROOT_DIR/scripts/find-api-calls.sh" "$TMP_DIR" --auth)"
assert_contains "$auth_output" "Authorization"
assert_contains "$auth_output" "BASE_URL"

all_output="$(bash "$ROOT_DIR/scripts/find-api-calls.sh" "$TMP_DIR")"
assert_contains "$all_output" "GraphQL / Apollo"
assert_contains "$all_output" "WebSocket"
assert_contains "$all_output" "gRPC"
assert_contains "$all_output" "Certificate Pinning & Network Security"
assert_contains "$all_output" "Resource URLs"
assert_contains "$all_output" "https://cdn.example.com/assets/"

echo "find-api-calls network extraction checks passed"
