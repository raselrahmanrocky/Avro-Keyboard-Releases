[CmdletBinding()]
param(
    [string]$Repo = $env:GH_REPO,
    [string]$Token = $env:GITHUB_TOKEN
)

if (-not $Repo) {
    $Repo = $env:GITHUB_REPOSITORY
}
if (-not $Token -and $env:GH_TOKEN) {
    $Token = $env:GH_TOKEN
}

Write-Host "Fetching live non-draft releases for $Repo..."

# 1. Fetch live releases using GitHub CLI
$releasesJson = gh release list --repo $Repo --limit 30 --json tagName,isPrerelease,isDraft | ConvertFrom-Json
$activeReleases = @($releasesJson | Where-Object { -not $_.isDraft })

# =========================================================================
# ZERO-STATE HANDLER: যদি কোনো রিলিজ না থাকে (সব ডিলিট হয়ে গেছে)
# =========================================================================
if ($activeReleases.Count -eq 0) {
    Write-Host "No active releases found in repository. Removing stale manifest files..."
    
    if (Test-Path "versioninfo.xml") {
        Remove-Item -Path "versioninfo.xml" -Force
        Write-Host "Deleted stale versioninfo.xml"
    }
    if (Test-Path "versioninfo_beta.xml") {
        Remove-Item -Path "versioninfo_beta.xml" -Force
        Write-Host "Deleted stale versioninfo_beta.xml"
    }

    if ($env:GITHUB_OUTPUT) {
        "stable=" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "beta="   | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
    exit 0
}

# =========================================================================
# CLASSIFICATION: Stable এবং Beta নির্ধারণ
# =========================================================================
$stableRel = $activeReleases | Where-Object { (-not $_.isPrerelease) -and ($_.tagName -notlike '*-beta*') } | Select-Object -First 1
$betaRel   = $activeReleases | Where-Object { ($_.isPrerelease -eq $true) -or ($_.tagName -like '*-beta*') } | Select-Object -First 1

# Fallbacks
if (-not $betaRel) {
    Write-Host "No beta release found. Beta channel will fall back to stable release."
    $betaRel = $stableRel
}
if (-not $stableRel) {
    Write-Host "No stable release found. Falling back to newest release."
    $stableRel = $activeReleases[0]
}

# =========================================================================
# XML GENERATOR FUNCTION
# =========================================================================
function Generate-ManifestXml {
    param($release)
    if (-not $release) { return $null }

    $tag = $release.tagName
    Write-Host "Generating manifest for tag: $tag"
    $relData = gh release view $tag --repo $Repo --json assets,publishedAt | ConvertFrom-Json
    $assets = @($relData.assets)

    # Architecture asset discovery
    $setup32 = $assets | Where-Object { $_.name -like '*setup*.exe' -and ($_.name -like '*win32*' -or $_.name -like '*x86*') } | Select-Object -First 1
    $setup64 = $assets | Where-Object { $_.name -like '*setup*.exe' -and ($_.name -like '*win64*' -or $_.name -like '*x64*') } | Select-Object -First 1
    $legacy  = $assets | Where-Object { $_.name -like '*setup*.exe' -or $_.name -like '*.exe' } | Select-Object -First 1

    $downloadUrl = if ($setup64) {
        "https://github.com/$Repo/releases/download/$tag/$($setup64.name)"
    } elseif ($legacy) {
        "https://github.com/$Repo/releases/download/$tag/$($legacy.name)"
    } else {
        "https://github.com/$Repo/releases/tag/$tag"
    }

    $downloadUrl32 = if ($setup32) { "https://github.com/$Repo/releases/download/$tag/$($setup32.name)" } else { $null }
    $downloadUrl64 = if ($setup64) { "https://github.com/$Repo/releases/download/$tag/$($setup64.name)" } else { $null }

    # Parse version numbers
    $cleanVer = $tag.TrimStart('v').TrimStart('V')
    $numOnly = ($cleanVer -split '-')[0]
    $parts = $numOnly.Split('.')

    $major = if ($parts.Length -gt 0 -and $parts[0] -ne '') { $parts[0] } else { "6" }
    $minor = if ($parts.Length -gt 1 -and $parts[1] -ne '') { $parts[1] } else { "0" }
    $rev   = if ($parts.Length -gt 2 -and $parts[2] -ne '') { $parts[2] } else { "0" }
    $build = if ($parts.Length -gt 3 -and $parts[3] -ne '') { $parts[3] } else { "0" }

    $date = if ($relData.publishedAt) {
        ([DateTime]$relData.publishedAt).ToString("yyyy-MM-dd")
    } else {
        (Get-Date).ToString("yyyy-MM-dd")
    }

    $xmlLines = @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<versioninfo>',
        "  <versionmajor>$major</versionmajor>",
        "  <versionminor>$minor</versionminor>",
        "  <versionrevision>$rev</versionrevision>",
        "  <versionbuild>$build</versionbuild>",
        "  <downloadurl>$downloadUrl</downloadurl>"
    )

    if ($downloadUrl32) { $xmlLines += "  <downloadurl32>$downloadUrl32</downloadurl32>" }
    if ($downloadUrl64) { $xmlLines += "  <downloadurl64>$downloadUrl64</downloadurl64>" }

    $xmlLines += @(
        "  <changelogurl>https://github.com/$Repo/releases/tag/$tag</changelogurl>",
        "  <productpageurl>https://github.com/$Repo</productpageurl>",
        "  <releasedate>$date</releasedate>",
        "  <namedversion>Avro Keyboard $cleanVer</namedversion>",
        '</versioninfo>'
    )

    return ($xmlLines -join "`r`n")
}

# 4. Generate XML files
$stableXml = Generate-ManifestXml $stableRel
$betaXml   = Generate-ManifestXml $betaRel

$utf8WithBom = New-Object System.Text.UTF8Encoding($true)

if ($stableXml) {
    [System.IO.File]::WriteAllText("versioninfo.xml", $stableXml, $utf8WithBom)
    Write-Host "Successfully generated versioninfo.xml from $($stableRel.tagName)"
}

if ($betaXml) {
    [System.IO.File]::WriteAllText("versioninfo_beta.xml", $betaXml, $utf8WithBom)
    Write-Host "Successfully generated versioninfo_beta.xml from $($betaRel.tagName)"
}

# 5. Set outputs for GitHub Actions
if ($env:GITHUB_OUTPUT) {
    "stable=$($stableRel.tagName)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "beta=$($betaRel.tagName)"     | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
