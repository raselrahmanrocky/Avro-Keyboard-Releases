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

$utf8WithBom = New-Object System.Text.UTF8Encoding($true)

# =========================================================================
# ZERO-STATE HANDLER: কোনো রিলিজ না থাকলে ডিফল্ট বেসলাইন (6.0.0.0) রাখবে
# যাতে ইউজার 404 এরর না পেয়ে "You are using latest version" দেখতে পায়।
# releasedate খালি রাখা হয় - নির্দিষ্ট তারিখ দিলে প্রতিটি dispatch তারিখ
# বদলে অর্থহীন churn commit তৈরি করে; ক্লায়েন্ট node-টি আবশ্যক, তাই
# সরিয়ে নয়, খালি রাখা।
# =========================================================================
if ($activeReleases.Count -eq 0) {
    Write-Host "No active releases found. Writing baseline manifests (6.0.0.0)..."
    
    $defaultXml = @"
<?xml version="1.0" encoding="utf-8"?>
<versioninfo>
  <versionmajor>6</versionmajor>
  <versionminor>0</versionminor>
  <versionrevision>0</versionrevision>
  <versionbuild>0</versionbuild>
  <downloadurl>https://github.com/$Repo</downloadurl>
  <changelogurl>https://github.com/$Repo</changelogurl>
  <productpageurl>https://github.com/$Repo</productpageurl>
  <releasedate></releasedate>
  <namedversion>Avro Keyboard 6.0.0</namedversion>
</versioninfo>
"@

    [System.IO.File]::WriteAllText("versioninfo.xml", $defaultXml.Trim(), $utf8WithBom)
    [System.IO.File]::WriteAllText("versioninfo_beta.xml", $defaultXml.Trim(), $utf8WithBom)
    Write-Host "Successfully written baseline 6.0.0.0 manifests."

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
# XML GENERATOR FUNCTION (লাইভ রিলিজ থেকে তৈরি)
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

    # Portable ZIP asset discovery (per-arch, optional)
    $portable32 = $assets | Where-Object { $_.name -like '*portable*.zip' -and ($_.name -like '*win32*' -or $_.name -like '*x86*') } | Select-Object -First 1
    $portable64 = $assets | Where-Object { $_.name -like '*portable*.zip' -and ($_.name -like '*win64*' -or $_.name -like '*x64*') } | Select-Object -First 1

    $downloadUrl = if ($setup64) {
        "https://github.com/$Repo/releases/download/$tag/$($setup64.name)"
    } elseif ($legacy) {
        "https://github.com/$Repo/releases/download/$tag/$($legacy.name)"
    } else {
        "https://github.com/$Repo/releases/tag/$tag"
    }

    $downloadUrl32 = if ($setup32) { "https://github.com/$Repo/releases/download/$tag/$($setup32.name)" } else { $null }
    $downloadUrl64 = if ($setup64) { "https://github.com/$Repo/releases/download/$tag/$($setup64.name)" } else { $null }

    $downloadUrlPortable32 = if ($portable32) { "https://github.com/$Repo/releases/download/$tag/$($portable32.name)" } else { $null }
    $downloadUrlPortable64 = if ($portable64) { "https://github.com/$Repo/releases/download/$tag/$($portable64.name)" } else { $null }

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
        ""
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
    if ($downloadUrlPortable32) { $xmlLines += "  <downloadurlportable32>$downloadUrlPortable32</downloadurlportable32>" }
    if ($downloadUrlPortable64) { $xmlLines += "  <downloadurlportable64>$downloadUrlPortable64</downloadurlportable64>" }

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
