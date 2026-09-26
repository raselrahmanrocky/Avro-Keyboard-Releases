<#
.SYNOPSIS
  Regenerates versioninfo.xml and versioninfo_beta.xml from the releases that
  currently exist on GitHub.

.DESCRIPTION
  Stateless by design: the script never looks at which event triggered it, so
  publishing, editing, prerelease-ing, unpublishing or deleting a release all
  end up with manifests that reflect reality after a sync.

  Channel rules:
    - a release is "beta" when it is flagged prerelease OR its tag ends in -beta
    - stable manifest <- newest non-beta, non-draft release
    - beta manifest   <- newest beta, non-draft release; falls back to the
      stable content when no beta release exists (beta users rejoin the stable
      channel cleanly); stable falls back to the newest release of any kind
      when no stable release exists.

  Output is deterministic: rerunning against the same release list produces
  byte-identical files (releasedate comes from the release's published_at).

  Requires only the GitHub REST API - no gh CLI - so it runs identically on
  GitHub Actions and locally.

.OUTPUTS
  versioninfo.xml / versioninfo_beta.xml in -OutDir (default: repo root).
  When $env:GITHUB_OUTPUT is set, writes stable= and beta= tag outputs for
  the workflow's later steps.

.EXAMPLE
  pwsh tools/gen_manifest.ps1

.EXAMPLE
  pwsh tools/gen_manifest.ps1 -OutDir $env:TEMP\manifest_dry
#>
[CmdletBinding()]
param(
  # owner/name; defaults to $env:GH_REPO (set by Actions) or the known repo.
  [string]$Repo = $env:GH_REPO,

  # Where the manifest files are written; defaults to the repository root.
  [string]$OutDir,

  # Optional API token (Actions passes secrets.GITHUB_TOKEN).
  [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'

if (-not $Repo)  { $Repo  = 'raselrahmanrocky/Avro-Keyboard-Releases' }
if (-not $OutDir) { $OutDir = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$headers = @{
  'User-Agent' = 'avro-manifest-sync'
  'Accept'     = 'application/vnd.github+json'
}
if ($Token) { $headers['Authorization'] = "Bearer $Token" }

# ---------------------------------------------------------------------------
# 1. Current release list (paginated) - never the triggering event payload.
# ---------------------------------------------------------------------------
$live = @()
$page = 1
do {
  $uri   = "https://api.github.com/repos/$Repo/releases?per_page=100&page=$page"
  $batch = @(Invoke-RestMethod -Uri $uri -Headers $headers)
  $live += @($batch | Where-Object { -not $_.draft })
  $page++
} while ($batch.Count -eq 100)

if ($live.Count -eq 0) { throw "No releases found on $Repo - refusing to overwrite manifests with empty data." }

$byDate = { if ($_.published_at) { [datetime]$_.published_at } else { [datetime]$_.created_at } }
$isBeta = { param($r) ($r.prerelease -or ($r.tag_name -match '-beta$')) }

$stables = @($live | Where-Object { -not (& $isBeta $_) } | Sort-Object $byDate -Descending)
$betas   = @($live | Where-Object { & $isBeta $_ }       | Sort-Object $byDate -Descending)

$stableRel = $stables | Select-Object -First 1
if (-not $stableRel) { $stableRel = $live | Sort-Object $byDate -Descending | Select-Object -First 1 }
$usedBetaFallback = $false
$betaRel = $betas | Select-Object -First 1
if (-not $betaRel) { $betaRel = $stableRel; $usedBetaFallback = $true }   # no beta release -> stable content

Write-Output ("live releases: {0} total ({1} stable-classified, {2} beta-classified)" -f $live.Count, $stables.Count, $betas.Count)

# ---------------------------------------------------------------------------
# 2. Per-release manifest data (asset discovery + URL building).
# ---------------------------------------------------------------------------
function Get-ManifestData {
  param($Rel)

  $tag   = $Rel.tag_name
  $base  = "https://github.com/$Repo"
  $assets = @($Rel.assets)

  # Architecture-tagged installers are preferred so each platform's clients
  # get their matching installer. Both naming schemes are recognized:
  #   current: AvroKeyboard-6.0.0-beta-win32-setup.exe / -win64-setup.exe
  #   legacy:  Setup_AvroKeyboard_x86.exe / Setup_AvroKeyboard_x64.exe
  # A plain Setup_AvroKeyboard.exe is the legacy downloadurl asset; it must
  # contain NO arch marker, otherwise the first new-style installer would be
  # mistaken for it.
  $setup32 = $assets | Where-Object { $_.name -like '*setup*.exe' -and ($_.name -like '*win32*' -or $_.name -like '*x86*') } | Select-Object -First 1
  $setup64 = $assets | Where-Object { $_.name -like '*setup*.exe' -and ($_.name -like '*win64*' -or $_.name -like '*x64*') } | Select-Object -First 1
  $legacy  = $assets | Where-Object {
      $_.name -like '*setup*.exe' -and
      $_.name -notlike '*win32*' -and $_.name -notlike '*win64*' -and
      $_.name -notlike '*x86*'   -and $_.name -notlike '*x64*'
  } | Select-Object -First 1
  if (-not $setup32 -and -not $setup64 -and -not $legacy) {
    $legacy = $assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1
  }

  $mkUrl = { param($asset) if ($asset) { "$base/releases/download/$tag/$($asset.name)" } else { $null } }

  # downloadurl serves legacy clients (they only read this node), so it must
  # always resolve to a real installer when one exists.
  $downloadUrl = & $mkUrl $legacy
  if (-not $downloadUrl) { $downloadUrl = & $mkUrl $setup32 }
  if (-not $downloadUrl) { $downloadUrl = & $mkUrl $setup64 }
  if (-not $downloadUrl) { $downloadUrl = "$base/releases/tag/$tag" }

  # Per-arch nodes are emitted only when an arch-tagged asset exists;
  # TUpdateCheck falls back to downloadurl otherwise.
  $downloadUrl32 = & $mkUrl $setup32
  $downloadUrl64 = & $mkUrl $setup64

  $cleanVer = $tag -replace '^[vV]', ''
  $numOnly  = ($cleanVer -split '-')[0]
  $parts    = $numOnly.Split('.')
  $major = if ($parts.Length -gt 0 -and $parts[0] -ne '') { $parts[0] } else { '0' }
  $minor = if ($parts.Length -gt 1 -and $parts[1] -ne '') { $parts[1] } else { '0' }
  $rev   = if ($parts.Length -gt 2 -and $parts[2] -ne '') { $parts[2] } else { '0' }
  $build = if ($parts.Length -gt 3 -and $parts[3] -ne '') { $parts[3] } else { '0' }

  [pscustomobject]@{
    Tag           = $tag
    CleanVer      = $cleanVer
    Major         = $major
    Minor         = $minor
    Rev           = $rev
    Build         = $build
    DownloadUrl   = $downloadUrl
    DownloadUrl32 = $downloadUrl32
    DownloadUrl64 = $downloadUrl64
    ChangeLogUrl  = "$base/releases/tag/$tag"
    ProductPage   = $base
    ReleaseDate   = ([datetime]$Rel.published_at).ToString('yyyy-MM-dd')
    NamedVersion  = "Avro Keyboard $cleanVer"
    Asset32       = if ($setup32) { $setup32.name } else { '' }
    Asset64       = if ($setup64) { $setup64.name } else { '' }
    AssetLegacy   = if ($legacy)  { $legacy.name  } else { '' }
  }
}

function New-ManifestXml {
  param($D)
  $lines = @(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<versioninfo>',
    "  <versionmajor>$($D.Major)</versionmajor>",
    "  <versionminor>$($D.Minor)</versionminor>",
    "  <versionrevision>$($D.Rev)</versionrevision>",
    "  <versionbuild>$($D.Build)</versionbuild>",
    "  <downloadurl>$($D.DownloadUrl)</downloadurl>"
  )
  if ($D.DownloadUrl32) { $lines += "  <downloadurl32>$($D.DownloadUrl32)</downloadurl32>" }
  if ($D.DownloadUrl64) { $lines += "  <downloadurl64>$($D.DownloadUrl64)</downloadurl64>" }
  $lines += @(
    "  <changelogurl>$($D.ChangeLogUrl)</changelogurl>",
    "  <productpageurl>$($D.ProductPage)</productpageurl>",
    "  <releasedate>$($D.ReleaseDate)</releasedate>",
    "  <namedversion>$($D.NamedVersion)</namedversion>",
    '</versioninfo>'
  )
  # UTF8 with BOM + CRLF, matching the format clients have always received.
  return ($lines -join "`r`n") + "`r`n"
}

# ---------------------------------------------------------------------------
# 3. Write both manifests.
# ---------------------------------------------------------------------------
$stableData = Get-ManifestData -Rel $stableRel
$betaData   = Get-ManifestData -Rel $betaRel
$utf8Bom    = New-Object System.Text.UTF8Encoding($true)

[IO.File]::WriteAllText((Join-Path $OutDir 'versioninfo.xml'),      (New-ManifestXml $stableData), $utf8Bom)
[IO.File]::WriteAllText((Join-Path $OutDir 'versioninfo_beta.xml'), (New-ManifestXml $betaData),   $utf8Bom)

Write-Output "stable : $($stableData.Tag)  (prerelease=$($stableRel.prerelease))"
Write-Output "  file : versioninfo.xml"
Write-Output "  url  : $($stableData.DownloadUrl)"
if ($stableData.Asset32)   { Write-Output "  x86  : $($stableData.Asset32)" }
if ($stableData.Asset64)   { Write-Output "  x64  : $($stableData.Asset64)" }
if ($stableData.AssetLegacy) { Write-Output "  legacy: $($stableData.AssetLegacy)" }
Write-Output "beta   : $($betaData.Tag)$(if ($usedBetaFallback) { '  (fallback: no beta release -> stable content)' })"
Write-Output "  file : versioninfo_beta.xml"
Write-Output "  url  : $($betaData.DownloadUrl)"

if ($env:GITHUB_OUTPUT) {
  Add-Content -Path $env:GITHUB_OUTPUT -Value "stable=$($stableData.Tag)"
  Add-Content -Path $env:GITHUB_OUTPUT -Value "beta=$($betaData.Tag)"
}
