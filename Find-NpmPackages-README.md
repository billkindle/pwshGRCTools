# Find-NpmPackages.ps1

## Overview

`Find-NpmPackages.ps1` scans the local machine for one or more npm packages
specified at runtime via `-TargetPackages`. It checks both the global npm prefix
and common developer project directories, then prints a formatted results table
with a per-package installation count summary. Useful for software inventory,
security audits, or verifying that specific packages are (or are not) present
on a workstation. Defaults to `axios` and `crypto-js` when no packages are
supplied.

## Prerequisites

### Requirements

- PowerShell 5.1 or later
- `npm` must be installed and available in the system `PATH` for global-install
  detection to work
- No additional PowerShell modules are required

## Usage

```powershell
# Scan for the default packages (axios, crypto-js)
.\Find-NpmPackages.ps1

# Scan for a single custom package
.\Find-NpmPackages.ps1 -TargetPackages 'lodash'

# Scan for multiple custom packages
.\Find-NpmPackages.ps1 -TargetPackages 'lodash', 'moment', 'express'

# Custom packages plus extra search roots
.\Find-NpmPackages.ps1 -TargetPackages 'webpack' -AdditionalPaths 'D:\Projects', 'E:\Work'

# Limit recursion depth to 3 levels
.\Find-NpmPackages.ps1 -MaxDepth 3

# Combine all parameters
.\Find-NpmPackages.ps1 -TargetPackages 'axios', 'node-fetch' -AdditionalPaths 'C:\CustomApps' -MaxDepth 4
```

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `TargetPackages` | `string[]` | `@('axios', 'crypto-js')` | One or more npm package names to search for. |
| `AdditionalPaths` | `string[]` | `@()` | Extra root directories to include in the local-project scan. |
| `MaxDepth` | `int` | `5` | Maximum folder depth when recursing to find `node_modules` directories. |

## Search Behavior

### 1 - Global installations

Runs `npm root -g` to obtain the global `node_modules` prefix, then checks
whether each package in `-TargetPackages` exists inside it.

### 2 - Local project installations

Recursively searches the following default roots for `node_modules` folders
(up to `MaxDepth` levels deep). Only roots that actually exist on disk are
scanned.

| Path |
| --- |
| `%USERPROFILE%\source` |
| `%USERPROFILE%\repos` |
| `%USERPROFILE%\projects` |
| `%USERPROFILE%\dev` |
| `%USERPROFILE%\Documents\GitHub` |
| `%USERPROFILE%\Documents\Projects` |
| `C:\inetpub\wwwroot` |
| `C:\dev` |
| `C:\repos` |
| `C:\projects` |

Nested `node_modules` folders (e.g., `node_modules\some-pkg\node_modules`) are
automatically excluded to avoid duplicate reporting.

Any paths supplied via `-AdditionalPaths` are appended to this list.

## Output

### Console table

Results are sorted by install type, package name, and path, then displayed as
an auto-sized table:

```text
=======================================================
  Results - axios, crypto-js package search
=======================================================

Package   Version  InstallType  Path
-------   -------  -----------  ----
axios     1.7.2    Global       C:\Users\jdoe\AppData\Roaming\npm\node_modules\axios
axios     1.6.8    Local        C:\repos\my-app\node_modules\axios
crypto-js 4.2.0    Local        C:\repos\my-app\node_modules\crypto-js
```

The report heading dynamically reflects whichever packages were passed to
`-TargetPackages`.

### Summary block

```text
Summary:
  axios        2 installation(s) found
  crypto-js    1 installation(s) found
```

## Examples

```powershell
# Example 1 - Scan for the default packages (axios, crypto-js)
.\Find-NpmPackages.ps1
```

```powershell
# Example 2 - Scan for a single package
.\Find-NpmPackages.ps1 -TargetPackages 'lodash'
```

```powershell
# Example 3 - Scan for multiple custom packages
.\Find-NpmPackages.ps1 -TargetPackages 'lodash', 'moment', 'express'
```

```powershell
# Example 4 - Include a corporate source tree on D:\
.\Find-NpmPackages.ps1 -TargetPackages 'webpack' -AdditionalPaths 'D:\CorpApps\WebPortal'
```

```powershell
# Example 5 - Shallow scan (2 levels) across extra paths
.\Find-NpmPackages.ps1 -TargetPackages 'axios', 'node-fetch' -AdditionalPaths 'D:\Projects', 'E:\ClientWork' -MaxDepth 2
```

```powershell
# Example 6 - Verbose output for troubleshooting
.\Find-NpmPackages.ps1 -TargetPackages 'axios' -Verbose
```

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| `Could not determine global npm root` warning | `npm` is not in `PATH` or not installed | Install Node.js/npm and ensure it is on the system `PATH` |
| `No common development directories found` warning | None of the default roots exist | Supply project roots with `-AdditionalPaths` |
| Script runs slowly | `MaxDepth` is too high on a large drive | Reduce with `-MaxDepth 2` or `-MaxDepth 3` |
| Package listed as `(unreadable)` | Corrupted or incomplete `package.json` | Reinstall the package in the affected project (`npm install`) |

## Notes

- The script is read-only; it makes no changes to the file system or npm
  configuration.
- Only `package.json` files directly inside a matching package folder are
  read; no network calls are made.
- Pass any number of package names via `-TargetPackages`. Omit it entirely to
  use the built-in defaults (`axios`, `crypto-js`).

## Version History

| Version | Date | Changes |
| --- | --- | --- |
| 1.0 | 2026-04-14 | Initial release |
| 1.1 | 2026-04-14 | Promoted `$TargetPackages` to a runtime parameter with default values |
