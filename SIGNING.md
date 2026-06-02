# Signing & Release

Releases are built, signed, notarized, and published automatically by
[`.github/workflows/release.yml`](.github/workflows/release.yml) whenever you push
a `v*` tag:

```sh
git tag v1.1.0
git push origin v1.1.0
```

The workflow imports your Developer ID cert, runs `build.sh`, notarizes with
`notarytool`, staples the ticket, packages a `.dmg`, and attaches it to a
**draft** GitHub Release (review it, then publish).

## Required repo secrets

Add these under **Settings → Secrets and variables → Actions → New repository
secret**. (Same names as the `platinumrelations-aws` repo — but secrets do not
carry across repos/orgs, so re-add them here.)

| Secret | What it is |
|--------|------------|
| `APPLE_CERTIFICATE` | base64 of your *Developer ID Application* `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | password protecting that `.p12` |
| `APPLE_SIGNING_IDENTITY` | `Developer ID Application: Nathan Brewer (2T95U247C9)` |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_PASSWORD` | **app-specific** password for that Apple ID |
| `APPLE_TEAM_ID` | `2T95U247C9` |

### Exporting the certificate to base64

From the Mac that holds the Developer ID cert:

```sh
# Keychain Access → export "Developer ID Application: …" as Certificates.p12
base64 -i Certificates.p12 | pbcopy   # paste into APPLE_CERTIFICATE
```

### App-specific password

Create at <https://appleid.apple.com> → Sign-In and Security → App-Specific
Passwords. Use that value for `APPLE_PASSWORD` (not your real Apple ID password).

## Local signed build

`build.sh` honors `SIGNING_IDENTITY` and `TEAM_ID` from the environment, falling
back to the committed defaults:

```sh
SIGNING_IDENTITY="Developer ID Application: Nathan Brewer (2T95U247C9)" ./build.sh
```

Local builds are signed but **not** notarized; only the CI release flow
notarizes. Unnotarized local builds will trip Gatekeeper on other machines.
