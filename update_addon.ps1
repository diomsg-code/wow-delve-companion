<#
.SYNOPSIS
A script to update addon files in WoW AddOns folder.

.DESCRIPTION
The script copies all required files according to YAML configuration file.

.PARAMETER yamlPath
Path to YAML configuration file.

.PARAMETER addonsLocation
Path to WoW AddOns folder.

.EXAMPLE
.\pack_addon_mainline.ps1 -yamlPath ".\\.pkgmeta" -addonsLocation "C:\\Program Files\\World of Warcraft\\_retail_\\Interface\\AddOns"
#>
param (
    [string]$yamlPath,
    [string]$addonsLocation
)

if ([string]::IsNullOrEmpty($addonsLocation)) {
    Write-Error "Addons folder is not provided. Check script args."
    exit 1
}
if ([string]::IsNullOrEmpty($yamlPath)) {
    Write-Error "YAML configuration is not provided. Check script args."
    exit 1
}

# ======= READ & PARSE YAML =======
# Use YAML file to make a list of ignored folders and files
$yamlContent = Get-Content $yamlPath

$packageAs = ""
$ignoreDirs = @()
$ignoreFiles = @()

foreach ($line in $yamlContent) {
    $trimmed = $line.Trim()
    if ($trimmed -like "package-as:*") {
        $packageAs = $trimmed.Substring($trimmed.IndexOf(":") + 1).Trim()
    }
    elseif ($trimmed -like "-*") {
        $item = $trimmed.TrimStart("-").Trim()

        if ($item.EndsWith(" #folder")) {
            $item = $item.Split('#')[0].Trim()
            $ignoreDirs += $item
            # Write-Output "Ignore folder: " $item
        }
        else {
            $ignoreFiles += $item
            # Write-Output "Ignore file: " $item
        }
    }
}

if ([string]::IsNullOrEmpty($packageAs)) {
    Write-Error "The YAML file must define a 'package-as' variable."
    exit 1
}

# Ensure that the YAML configuration file itself is ignored during copying.
$yamlFileName = Split-Path $yamlPath -Leaf
$ignoreFiles += $yamlFileName

# ======= DETERMINE DIRECTORIES =======
$sourceDir = Get-Location
$targetDir = Join-Path $addonsLocation $packageAs

if (Test-Path $targetDir) {
    Write-Output "Target folder '$targetDir' exists. Deleting..."
    Remove-Item $targetDir -Recurse -Force
}

Write-Output "Creating target folder '$targetDir'."
New-Item -ItemType Directory -Path $targetDir | Out-Null

# ======= COPY CONTENT WITH ROBOCOPY =======
# Build robocopy exclusion parameters:
#   /E  -> Copy all subdirectories (including empty ones)
#   /XD -> Exclude directories (separated by space)
#   /XF -> Exclude files (separated by space)
$sourcePath = $sourceDir.Path
$destinationPath = $targetDir

$xdParams = ""
if ($ignoreDirs.Count -gt 0) {
    $quotedDirs = $ignoreDirs | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
    }
    $xdParams = "/XD " + ($quotedDirs -join " ")
}

$xfParams = ""
if ($ignoreFiles.Count -gt 0) {
    $xfParams = "/XF " + ($ignoreFiles -join " ")
}

$robocopyCmd = "robocopy `"$sourcePath`" `"$destinationPath`" /E $xdParams $xfParams"
Invoke-Expression $robocopyCmd
