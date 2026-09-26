# Avro Keyboard Releases

Unofficial releases and update distribution for Avro Keyboard.

This repository hosts release artifacts and the machine-readable update
manifests that Avro Keyboard clients poll.

## Update manifests

Two files at the repository root (served via raw URLs) drive in-app update checks:

| File | Audience |
| --- | --- |
| `versioninfo.xml` | Stable channel |
| `versioninfo_beta.xml` | Beta channel (`BetaVersion` builds) |

Both are regenerated automatically by `.github/workflows/sync-manifests.yml`.

### Schema

```xml
<?xml version="1.0" encoding="utf-8"?>
<versioninfo>
  <versionmajor>6</versionmajor>
  <versionminor>0</versionminor>
  <versionrevision>0</versionrevision>
  <versionbuild>0</versionbuild>
  <downloadurl>...</downloadurl>
  <downloadurl32>...</downloadurl32>         <!-- optional -->
  <downloadurl64>...</downloadurl64>         <!-- optional -->
  <downloadurlportable32>...</downloadurlportable32> <!-- optional -->
  <downloadurlportable64>...</downloadurlportable64> <!-- optional -->
  <changelogurl>...</changelogurl>
  <productpageurl>...</productpageurl>
  <releasedate>YYYY-MM-DD</releasedate>
  <namedversion>Avro Keyboard 6.0.0</namedversion>
</versioninfo>
```

Field semantics:

- `downloadurl` — generic download target. Prefers the 64-bit setup, falls
  back to a legacy `*.exe`, then to the release tag page.
- `downloadurl32` / `downloadurl64` — per-architecture **setup** URLs, emitted
  only when a matching `*win32*`/`*x86*` or `*win64*`/`*x64*` `*setup*.exe`
  asset exists. Clients prefer the node matching their process architecture
  and fall back to `downloadurl` when the node is absent (legacy feeds).
- `downloadurlportable32` / `downloadurlportable64` — per-architecture
  **portable ZIP** URLs (`*portable*.zip` assets), optional. Portable-edition
  clients prefer these over the setup URLs; setup-edition clients ignore them.
- `releasedate` — publish date of the release backing this manifest. Must
  stay deterministic per release (never "today"), so repeated workflow runs
  produce no churn. The node is always present (the client requires it) but
  may be empty in the zero-state.
- All URLs are HEAD-verified by the client before an update is offered, so a
  stale manifest can never send a user to a 404.

### Channels and fallbacks

A release is classified by (in order of effect):

- **beta** — GitHub `prerelease` flag **or** tag matching `*-beta*`
- **stable** — otherwise (non-prerelease, tag not `*-beta*`)

Fallbacks when a channel has no release: beta falls back to the stable
release; if there is no stable release either, the stable manifest falls back
to the newest release of any kind.

### Zero-state

When the repository has no releases at all, both manifests are written with a
baseline `6.0.0` version and repository-root URLs. This keeps clients on
"You are using the latest version of Avro Keyboard" instead of showing a 404
error, and is intentionally deterministic (no per-run timestamps).

## Workflow

`sync-manifests.yml` runs on:

- release published / edited / prerelease-changed / deleted
- manual `workflow_dispatch`

It regenerates and commits both manifests, then (for stable releases) attaches
the canonical `versioninfo.xml` to the release itself for legacy clients that
download it directly.

## Naming convention

```
AvroKeyboard-<version>[-beta]-win32-setup.exe   (32-bit installer)
AvroKeyboard-<version>[-beta]-win64-setup.exe   (64-bit installer)
AvroKeyboard-<version>[-beta]-win32-portable.zip
AvroKeyboard-<version>[-beta]-win64-portable.zip
```

`-beta` appears only on pre-release builds; versions follow `6.x`.
