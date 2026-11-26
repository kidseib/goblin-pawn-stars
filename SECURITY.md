# Security

## Supported versions

Security fixes are applied to the latest `1.4.x` release. Older releases are kept
for reference but are not actively updated.

## What the addon can and cannot do

Goblin Pawn Stars is plain Lua 5.1 for World of Warcraft: Forever (Interface
16001). It does not ship an executable, installer, library or build step.

- It **reads** bags through `C_Container`; it never equips, sells, destroys or mails
  items.
- It never spends real gold or currency and never performs a game action.
- It uses no protected or secure APIs, no combat-log parsing, no secret values and no
  automation of gameplay.
- It makes no network requests, has no telemetry and calls no external service.
- Every risky client API is guarded or feature-checked; see `AGENTS.md`.

## Verify a release

The current release is **1.4.0**:

- File: `GoblinPawnStars-1.4.0.zip`
- Size: **2,992,832 bytes**
- SHA-256: `b493be01812857cb7e746a9e55d001d17eea200765106d7e99aba3d89419dfbc`
- VirusTotal: [file report](https://www.virustotal.com/gui/file/b493be01812857cb7e746a9e55d001d17eea200765106d7e99aba3d89419dfbc)
  — **no security vendors flagged this file as malicious**.

Check a downloaded ZIP before extracting it:

```powershell
# Windows PowerShell
Get-FileHash .\GoblinPawnStars-1.4.0.zip -Algorithm SHA256
```

```bash
# macOS / Linux
shasum -a 256 GoblinPawnStars-1.4.0.zip
# or: sha256sum GoblinPawnStars-1.4.0.zip
```

The same hash is published in the release notes. If it does not match, do not
install the file; download it again from the GitHub release.

VirusTotal is a useful second opinion, not a proof of safety. Some engines cannot
inspect ZIP archives, and a clean result does not replace reviewing the public
source. The addon is small, readable Lua; the full repository is available at
[github.com/kidseib/goblin-pawn-stars](https://github.com/kidseib/goblin-pawn-stars).

## Automated scans

`.github/workflows/virustotal.yml` runs when a GitHub release is published, and can
also be started manually from the Actions tab. It submits the release ZIP to
VirusTotal and appends the report link to that release's notes.

The workflow needs a repository secret named **`VT_API_KEY`**:

1. Sign in at [virustotal.com](https://www.virustotal.com/) and open your
   [API key page](https://www.virustotal.com/gui/my-apikey).
2. In GitHub, open **Settings → Secrets and variables → Actions → New repository
   secret**.
3. Name it `VT_API_KEY` and paste the key there. Never commit the key or paste it
   into an issue, chat or source file.
4. Run **Actions → VirusTotal → Run workflow** once to scan the current release.

If the secret is missing, the workflow stops with a setup message. The workflow
uses the free VirusTotal API's four-requests-per-minute limit; one ZIP per release
is well within it.

## Reporting a security issue

Please do not publish exploit details in a public issue. Use GitHub's **Report a
vulnerability** flow on the repository's Security tab, or contact the maintainer
through the repository. Include the addon version, Interface number and the
smallest reproduction you can.
