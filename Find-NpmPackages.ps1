#Requires -Version 5.1
<#
.SYNOPSIS
    Searches for one or more npm packages installed on the local machine.

.DESCRIPTION
    Find-NpmPackages checks two locations for each package name supplied via
    -TargetPackages:

      1. The global npm prefix (npm root -g)
      2. Common developer project directories (recursively, up to -MaxDepth)

    Results are displayed as a formatted table and a per-package count summary.
    Defaults to axios and crypto-js when -TargetPackages is omitted.

.PARAMETER TargetPackages
    One or more npm package names to search for.
    Defaults to @('axios', 'crypto-js').

.PARAMETER AdditionalPaths
    Extra root directories to include in the local-project scan.
    Only paths that exist on disk are scanned.

.PARAMETER MaxDepth
    Maximum folder depth when recursing for node_modules directories.
    Default is 5. Reduce this on large drives to improve performance.

.EXAMPLE
    .\Find-NpmPackages.ps1

    Scans for the default packages (axios, crypto-js) using all built-in
    search roots and a recursion depth of 5.

.EXAMPLE
    .\Find-NpmPackages.ps1 -TargetPackages 'lodash'

    Scans every default root for the lodash package only.

.EXAMPLE
    .\Find-NpmPackages.ps1 -TargetPackages 'lodash', 'moment', 'express'

    Scans for three packages at once across all default roots.

.EXAMPLE
    .\Find-NpmPackages.ps1 -TargetPackages 'webpack' -AdditionalPaths 'D:\Projects', 'E:\Work'

    Adds D:\Projects and E:\Work to the default search roots when looking
    for webpack.

.EXAMPLE
    .\Find-NpmPackages.ps1 -TargetPackages 'axios', 'node-fetch' -MaxDepth 2

    Scans for axios and node-fetch but limits recursion to 2 levels deep,
    useful on large drives or when scan speed is a concern.

.EXAMPLE
    .\Find-NpmPackages.ps1 -TargetPackages 'axios' -AdditionalPaths 'C:\CustomApps' -MaxDepth 3 -Verbose

    Full example combining all parameters with verbose output for
    troubleshooting.

.NOTES
    Author:  Bill Kindle (with AI assistance)
    Version: 1.1
    Created: 2026-04-14

    Requirements:
      - PowerShell 5.1 or later
      - npm must be installed and available in PATH for global detection
      - No additional PowerShell modules required

    The script is read-only; it makes no changes to the file system or npm
    configuration.
#>

[CmdletBinding()]
param(
    # One or more npm package names to search for
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetPackages = @('axios', 'crypto-js'),

    # Additional directories to scan for local installations
    [string[]]$AdditionalPaths = @(),

    # Max depth to recurse when searching for node_modules folders
    [int]$MaxDepth = 5
)

$Results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Find-PackageInNodeModules {
    param(
        [string]$NodeModulesPath,
        [string]$InstallType
    )

    foreach ($pkg in $TargetPackages) {
        $pkgPath = Join-Path $NodeModulesPath $pkg
        $pkgJson = Join-Path $pkgPath 'package.json'

        if (Test-Path $pkgJson) {
            try {
                $meta = Get-Content $pkgJson -Raw | ConvertFrom-Json
                $Results.Add([PSCustomObject]@{
                    Package     = $pkg
                    Version     = $meta.version
                    InstallType = $InstallType
                    Path        = $pkgPath
                })
            } catch {
                $Results.Add([PSCustomObject]@{
                    Package     = $pkg
                    Version     = '(unreadable)'
                    InstallType = $InstallType
                    Path        = $pkgPath
                })
            }
        }
    }
}

# -- 1. Global installations --------------------------------------------------
Write-Host ''
Write-Host 'Checking global npm installations...' -ForegroundColor Cyan

$globalRoot = $null
try {
    $globalRoot = (npm root -g 2>$null).Trim()
} catch {}

if ($globalRoot -and (Test-Path $globalRoot)) {
    Find-PackageInNodeModules -NodeModulesPath $globalRoot -InstallType 'Global'
} else {
    Write-Warning 'Could not determine global npm root (is npm in PATH?).'
}

# -- 2. Local installations - scan common dev directories --------------------
Write-Host 'Scanning for local project installations...' -ForegroundColor Cyan

$searchRoots = [System.Collections.Generic.List[string]]::new()

# Standard developer locations
@(
    "$env:USERPROFILE\source",
    "$env:USERPROFILE\repos",
    "$env:USERPROFILE\projects",
    "$env:USERPROFILE\dev",
    "$env:USERPROFILE\Documents\GitHub",
    "$env:USERPROFILE\Documents\Projects",
    'C:\inetpub\wwwroot',
    'C:\dev',
    'C:\repos',
    'C:\projects'
) | Where-Object { Test-Path $_ } | ForEach-Object { $searchRoots.Add($_) }

$AdditionalPaths | Where-Object { Test-Path $_ } | ForEach-Object { $searchRoots.Add($_) }

if ($searchRoots.Count -eq 0) {
    Write-Warning 'No common development directories found. Use -AdditionalPaths to specify search roots.'
}

foreach ($root in $searchRoots) {
    Write-Host ('  Scanning: ' + $root) -ForegroundColor DarkGray

    # Find all node_modules folders up to $MaxDepth levels deep
    $nodeModulesDirs = Get-ChildItem -Path $root -Filter 'node_modules' -Directory `
        -Recurse -Depth $MaxDepth -ErrorAction SilentlyContinue |
        # Exclude nested node_modules (inside another node_modules)
        Where-Object { $_.FullName -notmatch '\\node_modules\\.+\\node_modules' }

    foreach ($dir in $nodeModulesDirs) {
        Find-PackageInNodeModules -NodeModulesPath $dir.FullName -InstallType 'Local'
    }
}

# -- 3. Report ----------------------------------------------------------------
Write-Host '' -ForegroundColor Yellow
Write-Host '=======================================================' -ForegroundColor Yellow
Write-Host ('  Results - ' + ($TargetPackages -join ', ') + ' package search') -ForegroundColor Yellow
Write-Host '=======================================================' -ForegroundColor Yellow
Write-Host ''

if ($Results.Count -eq 0) {
    Write-Host 'No matching packages found.' -ForegroundColor Red
} else {
    $Results |
        Sort-Object InstallType, Package, Path |
        Format-Table -AutoSize -Property Package, Version, InstallType, Path
}

# Summary counts per package
Write-Host ''
Write-Host 'Summary:' -ForegroundColor Cyan
foreach ($pkg in $TargetPackages) {
    $count = ($Results | Where-Object { $_.Package -eq $pkg }).Count
    $color = if ($count -gt 0) { 'Green' } else { 'DarkGray' }
    Write-Host ('  ' + $pkg.PadRight(12) + ' ' + $count + ' installation(s) found') -ForegroundColor $color
}
