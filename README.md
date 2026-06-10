# android-reverse-skill

Codex skill for Android reverse engineering workflows: decompile APK, XAPK, JAR, and AAR files; inspect Android app structure; trace call flows; and extract HTTP API usage from Retrofit, OkHttp, Volley, WebView, and hardcoded URLs.

## Inspiration

This project is inspired by Simone Avogadro's Android reverse engineering skill:

https://github.com/SimoneAvogadro/android-reverse-engineering-skill

## Use With Codex

Install this repository as a Codex skill by placing it under a Codex-discovered skill directory, for example:

```text
.agents/skills/android-reverse-skill/
```

Then invoke it with:

```text
$android-reverse-skill
```

or ask Codex to decompile an APK, reverse engineer an Android app, extract API endpoints, or trace Android network call flows.

## Dependencies

Required:

- Java JDK 17+
- jadx

Optional:

- Vineflower/Fernflower
- dex2jar
- apktool
- adb

Run the bundled checker:

```bash
bash scripts/check-deps.sh
```

Install a missing dependency:

```bash
bash scripts/install-dep.sh jadx
```

## Examples

```bash
bash scripts/decompile.sh app.apk
bash scripts/decompile.sh --deobf app.apk
bash scripts/decompile.sh --engine both app.apk
bash scripts/find-api-calls.sh app-decompiled/sources/
```

## Legal Use

Use this skill only for lawful analysis of apps, libraries, or malware samples you are authorized to inspect, such as security research, interoperability analysis, malware analysis, education, or CTF work.

## License

Apache-2.0. See `LICENSE`.
