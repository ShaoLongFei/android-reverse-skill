---
name: android-reverse-skill
description: Decompile and analyze Android APK, XAPK, JAR, and AAR files with jadx and optional Fernflower/Vineflower; extract HTTP APIs from Retrofit, OkHttp, Volley, WebView, and hardcoded URLs; trace Android call flows from UI or app startup to network layers. Use for Android reverse engineering, APK decompilation, API endpoint extraction, Android app analysis, obfuscation-aware source review, or Chinese requests such as 反编译APK、安卓逆向、提取API、分析安卓应用、追踪调用链.
---

# Android Reverse Skill

Use this skill to decompile Android packages, inspect their architecture, trace call flows, and document HTTP API behavior. The bundled scripts live next to this file under `scripts/`; detailed techniques live under `references/`.

Operate only on apps, libraries, or malware samples the user is authorized to analyze. If the request appears to target unauthorized access, credential theft, or abuse, stop and keep the response to lawful analysis guidance.

## Path Setup

Resolve all bundled resources relative to this `SKILL.md` directory. Do not rely on plugin-specific root environment variables.

For macOS/Linux examples, set:

```bash
SKILL_DIR="/absolute/path/to/android-reverse-skill"
```

For Windows PowerShell examples, set:

```powershell
$SkillDir = "C:\absolute\path\to\android-reverse-skill"
```

If Codex has loaded this skill, use the path shown in the skills list or the current `SKILL.md` file path to derive `SKILL_DIR`.

## Workflow

### 1. Check Dependencies

Run the dependency checker before decompiling:

```bash
bash "$SKILL_DIR/scripts/check-deps.sh"
```

On Windows:

```powershell
& "$SkillDir\scripts\check-deps.ps1"
```

Required dependencies:
- Java JDK 17+
- `jadx`

Optional dependencies:
- Vineflower/Fernflower for higher-quality Java decompilation
- `dex2jar` for using Fernflower on APK/DEX inputs
- `apktool` for resource work
- `adb` for pulling packages from devices

If required dependencies are missing, install only after normal Codex approval rules are satisfied. The install scripts may download from the network, write to `~/.local`, modify shell profiles, use Homebrew, or ask for `sudo`.

```bash
bash "$SKILL_DIR/scripts/install-dep.sh" jadx
bash "$SKILL_DIR/scripts/install-dep.sh" vineflower
```

On Windows:

```powershell
& "$SkillDir\scripts\install-dep.ps1" jadx
```

Read `references/setup-guide.md` when installation fails or the user wants manual setup steps.

### 2. Decompile

Use the decompile wrapper for APK, XAPK, JAR, or AAR files:

```bash
bash "$SKILL_DIR/scripts/decompile.sh" [OPTIONS] <file>
```

On Windows:

```powershell
& "$SkillDir\scripts\decompile.ps1" [OPTIONS] <file>
```

Common options:
- `-o <dir>`: choose output directory
- `--deobf`: enable deobfuscation
- `--no-res`: skip resources for faster code-only output
- `--engine jadx|fernflower|both`: choose decompiler engine

Engine selection:
- Start with `jadx` for APK/XAPK and first-pass analysis.
- Use `fernflower` for JAR/AAR or difficult Java constructs.
- Use `both` when jadx has warnings or the user wants comparison output.
- Add `--deobf` for obfuscated apps or when package/class names are mostly short identifiers.

The scripts handle XAPK extraction and split/bundled APK detection. When a thin wrapper APK contains `base.apk`, look for the main source under `<output>/base/sources/`.

Read `references/jadx-usage.md` or `references/fernflower-usage.md` when tuning decompiler options.

### 3. Analyze Structure

After decompilation, inspect:
- `resources/AndroidManifest.xml` for launcher Activity, Application class, components, and network permissions.
- Top-level packages under `sources/` to separate app code from libraries.
- Packages or classes named `api`, `network`, `service`, `repository`, `data`, `retrofit`, `http`, `client`, or `interceptor`.
- Architecture signals such as Activity/Fragment, ViewModel, Repository, Presenter, Dagger/Hilt modules, or clean architecture layers.

For XAPK or bundled APKs, prioritize the base APK output.

### 4. Trace Call Flows

Start from user-visible or initialization entry points and follow calls toward network code:
- `Application.onCreate()` for dependency injection, base URLs, interceptors, and HTTP client setup.
- Main Activity or feature Activity for click listeners and UI events.
- ViewModel/Presenter methods to repositories/use cases.
- Repositories and service interfaces to Retrofit, OkHttp, Volley, WebView, or `HttpURLConnection`.
- DI modules for interface bindings and configured base URLs.

When code is obfuscated, anchor on string literals, Retrofit annotations, URL constants, HTTP method names, `Request.Builder`, interceptor setup, and auth header construction.

Read `references/call-flow-analysis.md` for deeper tracing patterns and commands.

### 5. Extract and Document APIs

Run the API search script for a broad sweep:

```bash
bash "$SKILL_DIR/scripts/find-api-calls.sh" <output>/sources/
```

Targeted searches:

```bash
bash "$SKILL_DIR/scripts/find-api-calls.sh" <output>/sources/ --retrofit
bash "$SKILL_DIR/scripts/find-api-calls.sh" <output>/sources/ --okhttp
bash "$SKILL_DIR/scripts/find-api-calls.sh" <output>/sources/ --urls
bash "$SKILL_DIR/scripts/find-api-calls.sh" <output>/sources/ --auth
```

On Windows:

```powershell
& "$SkillDir\scripts\find-api-calls.ps1" <output>\sources\ -Retrofit
& "$SkillDir\scripts\find-api-calls.ps1" <output>\sources\ -Urls
& "$SkillDir\scripts\find-api-calls.ps1" <output>\sources\ -Auth
```

For each endpoint, read surrounding source and document:
- HTTP method and path
- Base URL
- Path/query parameters
- Headers and authentication
- Request body and response type
- Calling chain from UI/startup to network layer
- Source file and line number

Use this concise format:

```markdown
### METHOD /path

- Source: `package.ApiService` (`ApiService.java:42`)
- Base URL: `https://api.example.com/v1`
- Params: path/query/body fields
- Headers/Auth: authorization scheme or token source
- Response: response type/model
- Called from: `Activity -> ViewModel -> Repository -> ApiService`
```

Read `references/api-extraction-patterns.md` for library-specific patterns and a fuller template.

## Deliverables

When the workflow completes, return:
- Decompiled output location
- Architecture summary
- API endpoint documentation
- Important call-flow map
- Dependency or decompiler warnings that affect confidence

Keep raw secrets, tokens, or private keys out of the final answer unless the user explicitly owns the app and asks for secret-handling guidance; prefer describing where they are loaded and how they are used.
