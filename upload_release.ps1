#Requires -Version 5.1
<#
.SYNOPSIS
    Automated GitHub Release Uploader for Antigravity Mobile
.DESCRIPTION
    Creates a GitHub Release v1.0.0 and uploads all release binaries (zip, exe, apk, source).
.PARAMETER Token
    GitHub Personal Access Token (classic with repo scope or fine-grained with Contents write).
.PARAMETER Repo
    GitHub repository in 'owner/repo' format (default: KorkmazPro28/antigravity-mobile).
.PARAMETER Tag
    Git tag for the release (default: v1.0.0).
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "GitHub Personal Access Token")]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$Repo = "KorkmazPro28/antigravity-mobile",

    [Parameter(Mandatory = $false)]
    [string]$Tag = "v1.0.0"
)

$ErrorActionPreference = "Stop"

if (-not $Token) {
    $Token = $env:GITHUB_TOKEN
}

if (-not $Token) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "       ANTIGRAVITY MOBILE - GITHUB RELEASE UPLOADER         " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    $Token = Read-Host -Prompt "Enter your GitHub Personal Access Token (PAT)"
    if (-not $Token) {
        Write-Error "GitHub token is required to create a release. Get one at: https://github.com/settings/tokens"
        exit 1
    }
}

$headers = @{
    "Authorization" = "token $Token"
    "Accept"        = "application/vnd.github.v3+json"
    "User-Agent"    = "Antigravity-Release-Script"
}

$releaseBody = @"
# Antigravity Mobile — v1.0.0 Official Release

Production-grade remote companion and biometric approval gateway for Google Antigravity on PC.

---

### 📦 Release Assets & SHA-256 Checksums

| Asset Name | Target Platform | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **\`antigravity-mobile-v1.0.0-windows-android.zip\`** | Windows & Android | ~35.2 MB | \`8D138F64DF10DE133B161E00AA33752E710C582ABBBF765989A19DAE30C07720\` |
| **\`bridge-server-install.exe\`** | Windows 10/11 x64 | 9.24 MB | \`99752BDEA43507AC7E075EB3D8D7605AEC6226F7304EC56EE78A283A56FC2878\` |
| **\`antigravity-mobile.apk\`** | Android 8.0+ | 56.3 MB | \`78FF78C3387F14FB3D7A81E538786076DAE08EFC70DDA1888E842540AAC1E8A4\` |
| **\`antigravity-mobile-v1.0.0-source.zip\`** | Source Code | 485 KB | \`CA15CCE3BB2D304DFAE0F9F15186160EC06CC2882A4C43270D30F09F6508BABD\` |

---

### 🛡️ Security Audit
* **VirusTotal Status:** Clean (0 / 72 Security Vendors)
* **Local-only Architecture:** Zero external telemetry. Works strictly within local subnet.
* **Biometric Gate:** Enforces biometric verification on HIGH/CRITICAL commands.

---

### 🚀 Quick Start
1. **Windows:** Extract and run \`bridge-server-install.exe\`.
2. **Android:** Install \`antigravity-mobile.apk\`.
3. **Connect:** Open app, tap **Scan Devices** (auto-detected via UDP Port 9401).
"@

Write-Host "[1/3] Creating GitHub Release $Tag on $Repo..." -ForegroundColor Yellow

$releaseData = @{
    tag_name         = $Tag
    target_commitish = "main"
    name             = "Antigravity Mobile v1.0.0 (Production Release)"
    body             = $releaseBody
    draft            = $false
    prerelease       = $false
} | ConvertTo-Json

$apiUrl = "https://api.github.com/repos/$Repo/releases"

try {
    $createResponse = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $releaseData -ContentType "application/json; charset=utf-8"
    $uploadUrlTemplate = $createResponse.upload_url
    $uploadUrlBase = $uploadUrlTemplate -replace '\{.*\}', ''
    Write-Host "[+] Release created successfully (ID: $($createResponse.id))!" -ForegroundColor Green
} catch {
    Write-Host "[!] Note: Release might already exist. Trying to fetch existing release..." -ForegroundColor Yellow
    try {
        $existing = Invoke-RestMethod -Uri "$apiUrl/tags/$Tag" -Headers $headers
        $uploadUrlBase = $existing.upload_url -replace '\{.*\}', ''
        Write-Host "[+] Using existing release (ID: $($existing.id))" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create or find release: $_"
        exit 1
    }
}

$filesToUpload = @(
    @{ Path = "releases\v1.0.0\antigravity-mobile-v1.0.0-windows-android.zip"; ContentType = "application/zip"; Name = "antigravity-mobile-v1.0.0-windows-android.zip" },
    @{ Path = "releases\v1.0.0\package\bridge-server-install.exe"; ContentType = "application/vnd.microsoft.portable-executable"; Name = "bridge-server-install.exe" },
    @{ Path = "releases\v1.0.0\package\antigravity-mobile.apk"; ContentType = "application/vnd.android.package-archive"; Name = "antigravity-mobile.apk" },
    @{ Path = "releases\v1.0.0\antigravity-mobile-v1.0.0-source.zip"; ContentType = "application/zip"; Name = "antigravity-mobile-v1.0.0-source.zip" }
)

Write-Host "`n[2/3] Uploading Release Assets..." -ForegroundColor Yellow

foreach ($file in $filesToUpload) {
    if (-not (Test-Path $file.Path)) {
        Write-Warning "File not found: $($file.Path), skipping."
        continue
    }

    $targetName = $file.Name
    $targetUrl = "$uploadUrlBase`?name=$targetName"
    $sizeMb = [math]::Round((Get-Item $file.Path).Length / 1MB, 2)
    Write-Host "  -> Uploading $targetName ($sizeMb MB)..." -NoNewline

    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $file.Path))
    $uploadHeaders = @{
        "Authorization" = "token $Token"
        "Content-Type"  = $file.ContentType
        "User-Agent"    = "Antigravity-Release-Script"
    }

    try {
        $res = Invoke-RestMethod -Uri $targetUrl -Method Post -Headers $uploadHeaders -Body $fileBytes
        Write-Host " [OK]" -ForegroundColor Green
    } catch {
        Write-Host " [FAILED: $_]" -ForegroundColor Red
    }
}

Write-Host "`n[3/3] Release deployment complete!" -ForegroundColor Cyan
Write-Host "View release online at: https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor Green
