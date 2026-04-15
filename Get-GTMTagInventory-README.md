# Get-GTMTagInventory

GRC audit script that inventories Google Tag Manager containers and third-party tracking
technologies found on one or more websites. Produces PowerShell objects, a timestamped CSV,
or a multi-sheet Excel workbook suitable for compliance workpapers.

## Overview

`Get-GTMTagInventory.ps1` supports two primary audit modes:

- **Web Scan** — Fetches the HTML source of each target URL and matches it against a
  library of 35+ vendor-specific patterns (advertising pixels, analytics platforms,
  consent management tools, session-replay tools, marketing automation, customer
  support widgets, payment processors, and more). No credentials required.

- **GTM API** — Calls the Google Tag Manager Management API v2 to enumerate every tag,
  trigger, and variable inside a GTM account. Returns richer detail (tag type, active/paused
  status, workspace) but requires an OAuth2 bearer token.

Key GRC features:

- Risk classification: Low / Medium / High / Critical
- GDPR and CCPA relevance flags per tag
- Vendor country-of-domicile for cross-border transfer assessment
- Optional approved-tag baseline comparison to flag unauthorized tags
- Timestamped export suitable for audit workpapers

## Prerequisites

### All modes

- PowerShell 5.1 or 7.x
- Network access to target URLs (web scan mode)

### Excel output (optional)

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

### GTM API mode

1. Install the gcloud CLI: <https://cloud.google.com/sdk/docs/install>
2. Authenticate: `gcloud auth login`
3. Enable the Tag Manager API in your GCP project
4. Generate a token: `gcloud auth print-access-token`

## Usage

### Array mode (web scan)

```powershell
.\Get-GTMTagInventory.ps1 -Urls "https://www.example.com"
```

### Multiple URLs — filter pipeline results

```powershell
$findings = .\Get-GTMTagInventory.ps1 -Urls @("https://site1.com","https://site2.com")
$findings | Where-Object { $_.RiskLevel -eq 'High' } | Format-Table -AutoSize
```

### CSV mode — export to Excel

```powershell
.\Get-GTMTagInventory.ps1 -CsvPath ".\audit-sites.csv" -OutputFormat Excel -OutputPath "C:\Audit"
```

### Interactive mode — save to CSV

```powershell
.\Get-GTMTagInventory.ps1 -Interactive -OutputFormat CSV
```

### GTM API mode — full container inventory

```powershell
$token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
.\Get-GTMTagInventory.ps1 -GTMAccountId "123456789" -BearerToken $token -OutputFormat Excel
```

### Compliance baseline comparison

```powershell
.\Get-GTMTagInventory.ps1 -Urls "https://www.example.com" `
    -ApprovedTagsPath ".\approved-tags.csv" -OutputFormat CSV
```

### Deep scan including linked scripts

```powershell
.\Get-GTMTagInventory.ps1 -Urls "https://www.example.com" -ScanLinkedScripts -OutputFormat Excel
```

## CSV File Format

### Input — URL list (`-CsvPath`)

The file must contain a `Url` column. Additional columns are ignored.

```csv
Url
https://www.site1.com
https://www.site2.com
https://shop.site3.com/checkout
```

### Input — Approved tags baseline (`-ApprovedTagsPath`)

Used to flag tags not on the organization's approved list. Required columns: `TagName`,
`Category`.

```csv
TagName,Category
Google Tag Manager,Tag Management
Google Analytics 4,Analytics
OneTrust,Privacy / Consent
```

## Parameters

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `-Urls` | `string[]` | Array set | — | One or more website URLs to scan |
| `-CsvPath` | `string` | CSV set | — | Path to CSV with `Url` column |
| `-Interactive` | `switch` | Interactive set | — | Enter URLs interactively |
| `-GTMAccountId` | `string` | GTMApi set | — | Numeric GTM Account ID |
| `-BearerToken` | `SecureString` | GTMApi set | — | OAuth2 token for GTM API v2 |
| `-OutputFormat` | `string` | No | `Object` | `Object`, `CSV`, or `Excel` |
| `-OutputPath` | `string` | No | `(cwd)` | Directory or file path for export |
| `-ApprovedTagsPath` | `string` | No | — | CSV baseline for compliance comparison |
| `-ScanLinkedScripts` | `switch` | No | Off | Also scan externally linked JS files |
| `-SkipSSLValidation` | `switch` | No | Off | Bypass TLS cert check (lab use only) |
| `-TimeoutSeconds` | `int` | No | `30` | HTTP request timeout (5–300) |
| `-DelayMilliseconds` | `int` | No | `500` | Delay between requests (0–10000) |
| `-UserAgent` | `string` | No | Chrome UA | Custom User-Agent string |

## Tag Library

The script detects the following tracking technologies:

### Tag Management

| Tag | Risk | GDPR |
| --- | --- | --- |
| Google Tag Manager | Medium | Yes |
| Segment | Medium | Yes |
| Tealium iQ | Medium | Yes |
| Adobe Launch / DTM | Medium | Yes |

### Analytics

| Tag | Risk | GDPR |
| --- | --- | --- |
| Google Analytics 4 | Medium | Yes |
| Google Analytics Universal | Medium | Yes |
| Adobe Analytics | Medium | Yes |
| Microsoft Clarity | High | Yes |
| Hotjar | High | Yes |
| FullStory | High | Yes |
| Heap Analytics | High | Yes |
| Mixpanel | Medium | Yes |
| Amplitude | Medium | Yes |
| Quantcast | High | Yes |
| Nielsen | High | Yes |

### Advertising

| Tag | Risk | GDPR |
| --- | --- | --- |
| TikTok Pixel | **Critical** | Yes |
| Facebook / Meta Pixel | High | Yes |
| Google Ads | High | Yes |
| Google DoubleClick / CM360 | High | Yes |
| LinkedIn Insight Tag | High | Yes |
| Twitter / X Pixel | High | Yes |
| Snapchat Pixel | High | Yes |
| Pinterest Tag | High | Yes |
| Microsoft Bing Ads / UET | High | Yes |

### Marketing Automation

| Tag | Risk | GDPR |
| --- | --- | --- |
| HubSpot Tracking | High | Yes |
| Marketo Munchkin | High | Yes |
| Salesforce Pardot | High | Yes |

### Customer Support

| Tag | Risk | GDPR |
| --- | --- | --- |
| Intercom | Medium | Yes |
| Drift | Medium | Yes |
| Zendesk | Medium | Yes |

### Other

| Tag | Category | Risk | GDPR |
| --- | --- | --- | --- |
| OneTrust | Privacy / Consent | Low | Yes |
| Cookiebot | Privacy / Consent | Low | Yes |
| TrustArc | Privacy / Consent | Low | Yes |
| Optimizely | A/B Testing | Medium | Yes |
| Google reCAPTCHA | Security | Low | Yes |
| Stripe | Payment | Medium | Yes |
| PayPal | Payment | Medium | Yes |

## Output

### PowerShell object schema

Each result object contains the following properties:

| Property | Description |
| --- | --- |
| `ScanTimestamp` | Date/time the scan was initiated |
| `SourceUrl` | URL that was scanned (or GTM account reference) |
| `TagName` | Matched vendor or technology name |
| `TagIdentifier` | Extracted IDs or matched strings (e.g., `GTM-ABC1234`) |
| `Category` | Tag category (Analytics, Advertising, etc.) |
| `RiskLevel` | Low / Medium / High / Critical |
| `GDPRRelevant` | Whether the tag is relevant to GDPR compliance |
| `CCPARelevant` | Whether the tag is relevant to CCPA compliance |
| `DataCollected` | Summary of data types collected by this vendor |
| `VendorCountry` | Country where vendor data is primarily processed |
| `ContentSource` | Where the tag was found (Page HTML, Linked Script, GTM API) |
| `Source` | `WebScan` or `GTMApi` |
| `ApprovedStatus` | `Approved`, `UNAPPROVED`, `Unknown`, or `N/A` |
| `Notes` | Compliance notes and audit guidance |

### Example console output

```text
[INFO] Get-GTMTagInventory v1.0 - GRC Tag Audit
[INFO] Scan started: 2026-04-14 10:30:00
[INFO] Mode: Web Scan
[INFO] Scanning 1 URL(s)...
[INFO] Scanning: https://www.example.com
  [OK] Found 4 tag type(s)

======================================================
  GTM Tag Inventory - Scan Complete
======================================================
  Total findings  : 4
  Scan duration   : 3 second(s)
  Scan errors     : 0

  Findings by Risk Level:
Risk Level  Count
----------  -----
High        2
Low         1
Medium      1

  Findings by Category:
Category          Count
--------          -----
Advertising       2
Analytics         1
Privacy / Consent 1
======================================================
```

### Excel workbook sheets

When using `-OutputFormat Excel`, the workbook contains up to four sheets:

| Sheet | Contents |
| --- | --- |
| All Tags | Full inventory of all detected tags |
| High Risk | Tags with Risk Level of High or Critical |
| Unapproved Tags | Tags not in the approved baseline (only when `-ApprovedTagsPath` used) |
| Advertising | All advertising/pixel tags |

## Validation Layers

1. **URL format validation** — Rejects malformed URLs before scanning begins
2. **HTTP response validation** — Catches 4xx/5xx errors and timeout failures per URL
3. **CSV column validation** — Verifies required columns exist before processing
4. **Baseline column validation** — Verifies `TagName` column exists in approved-tags CSV
5. **Module availability check** — Detects missing ImportExcel and falls back to CSV

## Troubleshooting

### No tags detected on a page

Many tags load asynchronously via JavaScript after the initial page HTML is received.
Use `-ScanLinkedScripts` to fetch and scan external `.js` files, which may contain the
tag initialization code.

### HTTP 403 or connection errors

Some sites block non-browser HTTP clients. Try adjusting `-UserAgent` to match a real
browser or adding `-DelayMilliseconds 2000` to avoid rate limiting.

### SSL certificate errors

Use `-SkipSSLValidation` only in authorized test environments. Never use against
production websites without written authorization.

### ImportExcel not found

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

If you cannot install modules, omit `-OutputFormat Excel`. The script automatically
falls back to CSV output and shows an informational message.

### GTM API 401 Unauthorized

The bearer token has expired (tokens are typically valid for 1 hour). Regenerate:

```powershell
$token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
```

### GTM API 403 Forbidden

The authenticated account lacks access to the specified GTM account. Verify that the
account has at least Read permission in GTM at Admin > User Management.

## Best Practices

- Run web scans against staging or UAT environments first to verify connectivity before
  targeting production URLs.
- Use `-DelayMilliseconds 1000` or higher when scanning more than 10 URLs to avoid
  appearing as an automated scraper.
- Combine with `-ScanLinkedScripts` for more thorough coverage during formal audits,
  but expect longer scan times for pages with many external scripts.
- Store the approved-tags baseline CSV in source control so that changes are tracked
  and reviewed as part of a tag governance process.
- Schedule periodic scans (e.g., weekly CI jobs) and compare output CSV files to
  detect unauthorized tag additions between audits.
- Pipe results to `Export-Csv` or `ConvertTo-Json` for integration with GRC platforms
  or SIEM systems.

## Security Considerations

- This script is **read-only** and cannot modify GTM configurations.
- Bearer tokens are passed as `SecureString` and extracted to an in-memory BSTR that is
  zeroed immediately after the API calls complete. The token is never written to disk,
  logs, or console output.
- Obtain **written authorization** before scanning websites you do not own or control.
- Web scan mode only reads publicly accessible HTML. It does not authenticate to the
  target website or access any protected content.
- Results CSV/Excel files may contain sensitive inventory data about your organization's
  marketing stack. Store exports in accordance with your data classification policy.

## GRC Compliance Notes

| Regulation | Relevance |
| --- | --- |
| GDPR Article 28 | Data processor agreements required for each third-party tag that processes EU personal data |
| GDPR Article 46 | Standard Contractual Clauses required for tags that transfer data to non-EEA countries |
| CCPA | Tags classified with `CCPARelevant = True` must be disclosed and may require opt-out mechanisms |
| HIPAA | Verify that no PHI flows through advertising or analytics tags on patient-facing pages |
| PCI DSS Req 6.4 | All scripts on payment pages must be explicitly authorized and integrity-monitored |

## Examples

```powershell
# 1. Quick audit of a single site - pipeline the objects anywhere
.\Get-GTMTagInventory.ps1 -Urls "https://www.example.com"

# 2. Audit multiple sites - pipeline filter for Critical tags only
.\Get-GTMTagInventory.ps1 -Urls @("https://site1.com","https://site2.com") |
    Where-Object { $_.RiskLevel -eq 'Critical' }

# 3. Bulk audit from CSV - Excel workbook for audit workpapers
.\Get-GTMTagInventory.ps1 -CsvPath ".\sites.csv" -OutputFormat Excel -OutputPath "C:\Audit\2026-Q2"

# 4. Approved-tag compliance check with CSV output
.\Get-GTMTagInventory.ps1 -CsvPath ".\sites.csv" `
    -ApprovedTagsPath ".\approved-tags.csv" -OutputFormat CSV

# 5. Full GTM API container inventory
$token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
.\Get-GTMTagInventory.ps1 -GTMAccountId "123456789" -BearerToken $token -OutputFormat Excel

# 6. Pipeline results into a second script for remediation ticketing
$unapproved = .\Get-GTMTagInventory.ps1 -CsvPath ".\sites.csv" -ApprovedTagsPath ".\approved.csv" |
    Where-Object { $_.ApprovedStatus -eq 'UNAPPROVED' }
$unapproved | ForEach-Object { New-ServiceNowTicket -Description "Unapproved tag: $($_.TagName) on $($_.SourceUrl)" }
```

## Version History

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-04-14 | Bill Kindle | Initial release |
