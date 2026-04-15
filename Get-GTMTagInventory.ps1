#Requires -Version 5.1

#region Script Header and Parameters

<#
.SYNOPSIS
    GRC tag audit: inventories Google Tag Manager containers and third-party tracking
    technologies found on one or more websites.

.DESCRIPTION
    Get-GTMTagInventory performs a governance, risk, and compliance (GRC) audit of web
    tracking technologies. It operates in two primary modes:

    WEB SCAN MODE (Array / CSV / Interactive):
      Fetches the HTML source of each target URL and applies a library of over 35
      vendor-specific regex patterns to identify Google Tag Manager containers,
      analytics platforms, advertising pixels, consent management tools, session-replay
      tools, customer-support widgets, payment processors, and other third-party trackers.
      No authentication or credentials are required. Only public page HTML is read.

    GTM API MODE (GTMApi):
      Calls the Google Tag Manager Management API v2 to enumerate every tag, trigger,
      and variable configured inside a GTM account. Returns richer detail than web
      scanning (tag type, active/paused status, firing rules, workspace) but requires
      an OAuth2 bearer token with the tagmanager.readonly scope.

    INPUT METHODS:
      -Urls          Pass URLs as a string array (Array parameter set)
      -CsvPath       Load from CSV with a 'Url' column (CSV parameter set)
      -Interactive   Enter URLs interactively at the prompt (Interactive parameter set)
      -GTMAccountId  Target a GTM account via API (GTMApi parameter set)

    OUTPUT FORMATS:
      Object (default) - PSCustomObjects returned to the pipeline for further use
      CSV              - Timestamped CSV file in OutputPath directory
      Excel            - Multi-sheet Excel workbook (requires the ImportExcel module)

    GRC AUDIT FEATURES:
      - Risk classification (Low / Medium / High / Critical) for each tag category
      - GDPR and CCPA relevance flags
      - Vendor country-of-domicile for cross-border data transfer assessment
      - Optional approved-tag baseline comparison to flag unauthorized tags
      - Timestamped audit-evidence export suitable for compliance workpapers

.PARAMETER Urls
    One or more website URLs to scan. Must include scheme (e.g. https://example.com).
    Used with the 'Array' parameter set.

.PARAMETER CsvPath
    Path to a CSV file that contains a 'Url' column. Additional columns are ignored.
    Used with the 'CSV' parameter set.

.PARAMETER Interactive
    Prompts the operator to enter URLs one at a time at the console.
    Used with the 'Interactive' parameter set.

.PARAMETER GTMAccountId
    Numeric Google Tag Manager Account ID.
    Find it in the GTM UI at Admin > Account Settings > Account ID.
    Used with the 'GTMApi' parameter set.

.PARAMETER BearerToken
    OAuth2 access token for the GTM Management API v2, stored as a SecureString.
    Generate with gcloud and convert:
      $token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
    Required scope: https://www.googleapis.com/auth/tagmanager.readonly
    Used with the 'GTMApi' parameter set.

.PARAMETER OutputFormat
    Result format. Accepts: Object (default), CSV, Excel.
    Object  - PSCustomObjects on the pipeline. Best for further script composition.
    CSV     - Exports to a timestamped CSV in OutputPath.
    Excel   - Creates a multi-sheet workbook (requires: Install-Module ImportExcel).

.PARAMETER OutputPath
    Directory (or full file path) for CSV or Excel output.
    Defaults to the current working directory with an auto-generated timestamped name.

.PARAMETER ApprovedTagsPath
    Optional path to a CSV baseline file containing approved tags.
    Required columns: TagName, Category
    Any detected tag not on the list is flagged 'UNAPPROVED' in output.

.PARAMETER ScanLinkedScripts
    Also fetches and scans external JavaScript files referenced on each page.
    Increases coverage of asynchronously-loaded tags but extends scan time.

.PARAMETER SkipSSLValidation
    Bypasses TLS certificate validation during web scanning.
    WARNING: Use only in authorized lab or test environments.

.PARAMETER TimeoutSeconds
    HTTP request timeout in seconds. Default: 30. Range: 5-300.

.PARAMETER DelayMilliseconds
    Delay between HTTP requests to avoid rate limiting. Default: 500. Range: 0-10000.

.PARAMETER UserAgent
    Custom User-Agent header sent with each web request.
    Defaults to a standard Chrome browser string.

.EXAMPLE
    .\Get-GTMTagInventory.ps1 -Urls "https://www.example.com"

    Scans a single website and returns tag findings as PowerShell objects.

.EXAMPLE
    $findings = .\Get-GTMTagInventory.ps1 -Urls @("https://site1.com","https://site2.com")
    $findings | Where-Object { $_.RiskLevel -eq 'High' } | Format-Table -AutoSize

    Scans two sites and filters for high-risk tags.

.EXAMPLE
    .\Get-GTMTagInventory.ps1 -CsvPath ".\audit-sites.csv" -OutputFormat Excel -OutputPath "C:\Audit"

    Loads URLs from a CSV and exports findings to an Excel workbook.

.EXAMPLE
    .\Get-GTMTagInventory.ps1 -Interactive -OutputFormat CSV

    Prompts for URLs interactively and saves results to a timestamped CSV.

.EXAMPLE
    $token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
    .\Get-GTMTagInventory.ps1 -GTMAccountId "123456789" -BearerToken $token -OutputFormat Excel

    Uses the GTM API to enumerate all tags in a GTM account and exports to Excel.

.EXAMPLE
    .\Get-GTMTagInventory.ps1 -Urls "https://www.example.com" `
        -ApprovedTagsPath ".\approved-tags.csv" -OutputFormat CSV

    Compares detected tags against an approved-tag baseline and flags unauthorized tags.

.NOTES
    Author:  Bill Kindle (with AI assistance)
    Version: 1.0
    Created: 2026-04-14

    Requires:
      - PowerShell 5.1 or 7.x
      - Network access to target URLs
      - ImportExcel module (optional, for Excel output):
          Install-Module ImportExcel -Scope CurrentUser

    Required Permissions:
      - Web Scan mode:  Read access to public URLs only (no credentials needed)
      - GTM API mode:   Google account with tagmanager.readonly scope on the GTM account

    Setup Instructions - GTM API Mode:
      1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
      2. Authenticate: gcloud auth login
      3. Enable the Tag Manager API in your GCP project
      4. Generate a token: gcloud auth print-access-token
      5. Convert to SecureString:
            $token = (gcloud auth print-access-token) | ConvertTo-SecureString -AsPlainText -Force
      6. Run: .\Get-GTMTagInventory.ps1 -GTMAccountId "YOUR_ACCOUNT_ID" -BearerToken $token

    Approved Tags Baseline CSV format (for -ApprovedTagsPath):
      TagName,Category
      "Google Tag Manager","Tag Management"
      "Google Analytics 4","Analytics"

    GRC / Compliance Context:
      - GDPR Article 28:  Processor agreements required for third-party tags collecting
                          personal data from EU residents.
      - CCPA:             Disclosure required for tags that sell personal information.
      - HIPAA:            PHI must not be transmitted to unauthorized third parties via tags.
      - PCI DSS Req 6.4:  Scripts on payment pages must be authorized and integrity-checked.

    Security Notes:
      - This script is READ-ONLY and cannot modify GTM configurations.
      - Bearer tokens are handled as SecureStrings and never written to disk or logs.
      - Obtain written authorization before scanning websites you do not own or control.
      - Use -SkipSSLValidation only in authorized testing environments.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low', DefaultParameterSetName = 'Array')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Interactive',
    Justification = 'Presence of this switch selects the Interactive parameter set; checked via Urls/CsvPath null tests in Get-TargetUrls')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ScanLinkedScripts',
    Justification = 'Boolean flag evaluated inside Invoke-WebScan via outer-scope variable reference')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Array')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Urls,

    [Parameter(Mandatory = $true, ParameterSetName = 'CSV')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
    [switch]$Interactive,

    [Parameter(Mandatory = $true, ParameterSetName = 'GTMApi')]
    [ValidateNotNullOrEmpty()]
    [string]$GTMAccountId,

    [Parameter(Mandatory = $true, ParameterSetName = 'GTMApi')]
    [System.Security.SecureString]$BearerToken,

    [ValidateSet('Object', 'CSV', 'Excel')]
    [string]$OutputFormat = 'Object',

    [string]$OutputPath = (Get-Location).Path,

    [ValidateScript({ if ($_) { Test-Path $_ -PathType Leaf } else { $true } })]
    [string]$ApprovedTagsPath,

    [switch]$ScanLinkedScripts,

    [switch]$SkipSSLValidation,

    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30,

    [ValidateRange(0, 10000)]
    [int]$DelayMilliseconds = 500,

    [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
)

#endregion Script Header and Parameters

#region Configuration

$ErrorActionPreference = 'Stop'
$Script:ScanStart = Get-Date
$Script:Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Tag signature library: Pattern, Category, RiskLevel, GDPRRelevant, CCPARelevant,
#                        DataCollected, VendorCountry, Notes
$Script:TagSignatures = [ordered]@{
    'Google Tag Manager' = @{
        Pattern       = '(?:GTM-[A-Z0-9]{4,10})|(?:googletagmanager\.com/gtm\.js)'
        Category      = 'Tag Management'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Container configuration; inherits all child tag data'
        VendorCountry = 'USA'
        Notes         = 'Container may load additional undisclosed third-party tags'
    }
    'Google Analytics 4' = @{
        Pattern       = '(?:G-[A-Z0-9]{8,12})|(?:gtag\.js\?id=G-)|(?:googletagmanager\.com/gtag/js)'
        Category      = 'Analytics'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Page views, events, user IDs, demographics, session data'
        VendorCountry = 'USA'
        Notes         = 'Data stored in USA; Standard Contractual Clauses required for EU transfer'
    }
    'Google Analytics Universal' = @{
        Pattern       = '(?:UA-\d{4,10}-\d{1,4})|(?:google-analytics\.com/analytics\.js)|(?:google-analytics\.com/ga\.js)'
        Category      = 'Analytics'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Page views, sessions, user IDs, IP addresses'
        VendorCountry = 'USA'
        Notes         = 'UA sunset July 2023; legacy presence indicates outdated implementation'
    }
    'Google Ads' = @{
        Pattern       = '(?:AW-\d{9,12})|(?:googleadservices\.com/pagead/conversion)|(?:google\.com/pagead/conversion)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Conversion events, remarketing audiences, behavioral data'
        VendorCountry = 'USA'
        Notes         = 'Consent required under GDPR; triggers remarketing cookie creation'
    }
    'Google DoubleClick / CM360' = @{
        Pattern       = '(?:doubleclick\.net)|(?:fls\.doubleclick)|(?:floodlight)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Cross-site behavioral data, ad impressions, conversions'
        VendorCountry = 'USA'
        Notes         = 'Cross-site tracking capability; high privacy risk'
    }
    'Facebook / Meta Pixel' = @{
        Pattern       = '(?:connect\.facebook\.net)|(?:fbq\s*\()|(?:facebook\.com/tr/)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Page views, conversion events, email hashes, behavioral profiles'
        VendorCountry = 'USA'
        Notes         = 'Data transferred to Meta; significant GDPR enforcement history'
    }
    'LinkedIn Insight Tag' = @{
        Pattern       = '(?:snap\.licdn\.com)|(?:linkedin\.com/li\.lms-analytics)|(?:li_fat_id)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Professional profile correlations, conversion events, retargeting audiences'
        VendorCountry = 'USA'
        Notes         = 'Can correlate visitors to professional LinkedIn profiles'
    }
    'Twitter / X Pixel' = @{
        Pattern       = '(?:static\.ads-twitter\.com)|(?:analytics\.twitter\.com)|(?:t\.co/i/adsct)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Conversion events, Twitter/X user ID cross-matching'
        VendorCountry = 'USA'
        Notes         = 'Cross-platform identity matching enabled'
    }
    'TikTok Pixel' = @{
        Pattern       = '(?:analytics\.tiktok\.com)|(?:ttq\.identify)|(?:tiktok\.com/i18n/pixel)'
        Category      = 'Advertising'
        RiskLevel     = 'Critical'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Behavioral events, conversion data, device fingerprinting'
        VendorCountry = 'China'
        Notes         = 'CRITICAL: Data may flow to China; high regulatory risk under GDPR and US state privacy laws'
    }
    'Pinterest Tag' = @{
        Pattern       = '(?:ct\.pinterest\.com)|(?:pintrk\s*\()'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Conversion events, audience behavioral data'
        VendorCountry = 'USA'
        Notes         = 'Consent required under GDPR'
    }
    'Microsoft Bing Ads / UET' = @{
        Pattern       = '(?:bat\.bing\.com)|(?:uetq\.push)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Conversion events, Universal Event Tracking behavioral data'
        VendorCountry = 'USA'
        Notes         = 'UET requires consent; data linked to Microsoft Advertising platform'
    }
    'Microsoft Clarity' = @{
        Pattern       = '(?:clarity\.ms/tag)|(?:clarity\.microsoft\.com)'
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Session recordings, heatmaps, mouse movements, form inputs'
        VendorCountry = 'USA'
        Notes         = 'Records full session replays; may inadvertently capture PII in form fields'
    }
    'Snapchat Pixel' = @{
        Pattern       = '(?:tr\.snapchat\.com)|(?:sc-static\.net/scevent)'
        Category      = 'Advertising'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Conversion events, behavioral audience profiles'
        VendorCountry = 'USA'
        Notes         = 'Consent required under GDPR; links to Snapchat ad platform'
    }
    'Hotjar' = @{
        Pattern       = "(?:static\.hotjar\.com)|(?:insights\.hotjar\.com)|(?:['""`"]hjid['""`"])"
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Session recordings, heatmaps, feedback polls, form analytics'
        VendorCountry = 'Malta/EU'
        Notes         = 'Captures user interactions including form inputs; potential PII exposure'
    }
    'FullStory' = @{
        Pattern       = '(?:fullstory\.com/s/fs\.js)|(?:fs\.identify)|(?:_fs_script)'
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Full DOM capture, complete session replay, user identification'
        VendorCountry = 'USA'
        Notes         = 'Captures all page content and DOM mutations; DPA required'
    }
    'Mixpanel' = @{
        Pattern       = '(?:cdn\.mxpnl\.com)|(?:mixpanel\.com/libs)|(?:mixpanel\.init)'
        Category      = 'Analytics'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Custom events, user properties, behavioral flows'
        VendorCountry = 'USA'
        Notes         = 'Product analytics; DPA required for EU user data processing'
    }
    'Amplitude' = @{
        Pattern       = '(?:cdn\.amplitude\.com)|(?:amplitude\.getInstance)|(?:amplitude\.init)'
        Category      = 'Analytics'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Product events, user properties, session data'
        VendorCountry = 'USA'
        Notes         = 'EU data residency option available; configure if processing EU user data'
    }
    'Heap Analytics' = @{
        Pattern       = '(?:cdn\.heapanalytics\.com)|(?:heap\.load)'
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Auto-captured events, all clicks, all form submissions'
        VendorCountry = 'USA'
        Notes         = 'Auto-captures all user interactions by default; high PII risk in form fields'
    }
    'Segment' = @{
        Pattern       = '(?:cdn\.segment\.com)|(?:segment\.io/analytics\.js)'
        Category      = 'Tag Management'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Event data forwarded to all configured downstream destinations'
        VendorCountry = 'USA'
        Notes         = 'CDP that forwards data to multiple vendors; audit all Segment destinations'
    }
    'Tealium iQ' = @{
        Pattern       = '(?:tags\.tiqcdn\.com)|(?:utag\.js)'
        Category      = 'Tag Management'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'All data collected by configured child tags'
        VendorCountry = 'USA'
        Notes         = 'Enterprise TMS; audit all configured tags and data layer mappings'
    }
    'Adobe Launch / DTM' = @{
        Pattern       = '(?:assets\.adobedtm\.com)|(?:launch-[a-z0-9]{8,}\.min\.js)'
        Category      = 'Tag Management'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Container for all Adobe Experience Cloud tags'
        VendorCountry = 'USA'
        Notes         = 'Adobe TMS; enumerate all configured rules, extensions, and data elements'
    }
    'Adobe Analytics' = @{
        Pattern       = '(?:omtrdc\.net)|(?:sc_strack)|(?:omniture\.com)'
        Category      = 'Analytics'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Page views, custom events, eVars, props, visitor IDs'
        VendorCountry = 'USA'
        Notes         = 'Enterprise analytics; DPA required; EU data collection endpoint available'
    }
    'HubSpot Tracking' = @{
        Pattern       = '(?:js\.hs-scripts\.com)|(?:js\.hs-analytics\.net)|(?:/hs/hsstatic)'
        Category      = 'Marketing Automation'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Contact identification, form submissions, behavioral lead scoring'
        VendorCountry = 'USA'
        Notes         = 'Identifies returning visitors by email; associates activity with CRM contacts'
    }
    'Marketo Munchkin' = @{
        Pattern       = '(?:munchkin\.marketo\.net)|(?:Munchkin\.init)'
        Category      = 'Marketing Automation'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'User identity, behavioral lead scoring, email engagement tracking'
        VendorCountry = 'USA'
        Notes         = 'Associates web activity with Marketo lead records in real time'
    }
    'Salesforce Pardot' = @{
        Pattern       = '(?:pi\.pardot\.com)|(?:go\.pardot\.com/l/)'
        Category      = 'Marketing Automation'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Prospect tracking, form completions, email engagement'
        VendorCountry = 'USA'
        Notes         = 'B2B marketing automation; identity resolution against Pardot prospect database'
    }
    'Intercom' = @{
        Pattern       = '(?:widget\.intercom\.io)|(?:intercomcdn\.com)|(?:Intercom\s*\()'
        Category      = 'Customer Support'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'User identity, chat messages, behavioral events'
        VendorCountry = 'USA'
        Notes         = 'User data shared with Intercom CRM; DPA available from Intercom'
    }
    'Drift' = @{
        Pattern       = '(?:js\.driftt\.com)|(?:drift\.com/drift-frame)'
        Category      = 'Customer Support'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'Chat conversations, user identity, behavioral scoring'
        VendorCountry = 'USA'
        Notes         = 'Conversational marketing; processes visitor identity and conversation data'
    }
    'Zendesk' = @{
        Pattern       = '(?:static\.zdassets\.com)|(?:zendesk\.com/embeddable_framework)'
        Category      = 'Customer Support'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'Support ticket data, user identity, satisfaction scores'
        VendorCountry = 'USA'
        Notes         = 'EEA data processing addendum available from Zendesk'
    }
    'Optimizely' = @{
        Pattern       = '(?:cdn\.optimizely\.com)|(?:optimizely\.com/public/[a-z0-9]+\.js)'
        Category      = 'A/B Testing'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Experiment assignment, impressions, conversion events'
        VendorCountry = 'USA'
        Notes         = 'Experiment platform; visitor bucketing data stored in USA'
    }
    'OneTrust' = @{
        Pattern       = '(?:cdn\.cookielaw\.org)|(?:optanon\.net)|(?:onetrust\.com/consent)'
        Category      = 'Privacy / Consent'
        RiskLevel     = 'Low'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Consent records, cookie preference data'
        VendorCountry = 'USA'
        Notes         = 'CMP detected; positive compliance indicator - verify consent gates all other tags'
    }
    'Cookiebot' = @{
        Pattern       = '(?:consent\.cookiebot\.com)|(?:cookiebot\.com/en/uc\.js)'
        Category      = 'Privacy / Consent'
        RiskLevel     = 'Low'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Consent records, automated cookie scan results'
        VendorCountry = 'Denmark/EU'
        Notes         = 'EU-based CMP; positive compliance indicator'
    }
    'TrustArc' = @{
        Pattern       = '(?:consent\.truste\.com)|(?:trustarc\.com/notice)'
        Category      = 'Privacy / Consent'
        RiskLevel     = 'Low'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Consent records, preference data'
        VendorCountry = 'USA'
        Notes         = 'Enterprise CMP; positive compliance indicator'
    }
    'Quantcast' = @{
        Pattern       = '(?:quantserve\.com/quant\.js)|(?:sealserver\.quantcast\.com)'
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Audience measurement, demographic inference, behavioral targeting data'
        VendorCountry = 'USA'
        Notes         = 'Audience analytics and data broker; user consent required'
    }
    'Nielsen' = @{
        Pattern       = '(?:secure-dcr\.imrworldwide\.com)|(?:imrworldwide\.com/v60\.js)'
        Category      = 'Analytics'
        RiskLevel     = 'High'
        GDPRRelevant  = $true
        CCPARelevant  = $true
        DataCollected = 'Audience measurement, demographics, content consumption ratings'
        VendorCountry = 'USA'
        Notes         = 'Media measurement vendor; cross-site tracking capability'
    }
    'Google reCAPTCHA' = @{
        Pattern       = '(?:google\.com/recaptcha)|(?:recaptcha/api\.js)'
        Category      = 'Security'
        RiskLevel     = 'Low'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'Browser fingerprint, behavioral signals for bot detection'
        VendorCountry = 'USA'
        Notes         = 'Bot detection; Google processes device fingerprint data; disclosure may be required'
    }
    'Stripe' = @{
        Pattern       = '(?:js\.stripe\.com/v[23])|(?:stripe\.com/stripe\.js)'
        Category      = 'Payment'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'Payment card data, fraud signals, device fingerprinting'
        VendorCountry = 'USA/Ireland'
        Notes         = 'PCI DSS compliant payment processor; Stripe Payments Europe entity available'
    }
    'PayPal' = @{
        Pattern       = '(?:paypal\.com/sdk/js)|(?:paypalobjects\.com)'
        Category      = 'Payment'
        RiskLevel     = 'Medium'
        GDPRRelevant  = $true
        CCPARelevant  = $false
        DataCollected = 'Payment data, PayPal account cross-correlation'
        VendorCountry = 'USA'
        Notes         = 'Payment processor; may link visitors to PayPal accounts'
    }
}

#endregion Configuration

#region Helper Functions - Output

function Write-Status {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Console-only status output per repository standard; not intended for pipeline use')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Success', 'Error', 'Warning', 'Info')]
        [string]$Type = 'Info'
    )

    $colorMap = @{
        Success = 'Green'
        Error   = 'Red'
        Warning = 'Yellow'
        Info    = 'Cyan'
    }
    Write-Host $Message -ForegroundColor $colorMap[$Type]
}

#endregion Helper Functions - Output

#region Helper Functions - Validation

function Test-UrlFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    return ($Url -match '^https?://[^\s/$.?#].[^\s]*$')
}

function Test-InputData {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[string]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RawUrls
    )

    $validated = [System.Collections.Generic.List[string]]::new()
    foreach ($u in $RawUrls) {
        $trimmed = $u.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if (Test-UrlFormat -Url $trimmed) {
            $validated.Add($trimmed)
        } else {
            Write-Status "[WARNING] Skipping invalid URL: $trimmed" -Type Warning
        }
    }
    return $validated
}

#endregion Helper Functions - Validation

#region Helper Functions - Input Collection

function Get-TargetUrls {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[string]])]
    param()

    $raw = [System.Collections.Generic.List[string]]::new()

    if ($Urls) {
        foreach ($url in $Urls) { $raw.Add($url) }
    } elseif ($CsvPath) {
        Write-Status "[INFO] Loading URLs from: $CsvPath" -Type Info
        $csvData = Import-Csv -Path $CsvPath
        if (-not ($csvData | Get-Member -Name 'Url' -MemberType NoteProperty -ErrorAction SilentlyContinue)) {
            throw "CSV file must contain a 'Url' column. Columns found: $(($csvData[0].PSObject.Properties.Name) -join ', ')"
        }
        foreach ($row in $csvData) {
            if (-not [string]::IsNullOrWhiteSpace($row.Url)) { $raw.Add($row.Url.Trim()) }
        }
        Write-Status "[OK] Loaded $($raw.Count) URL(s) from CSV" -Type Success
    } else {
        Write-Status "[INFO] Interactive mode - enter URLs one per line. Enter a blank line when done." -Type Info
        while ($true) {
            $entry = Read-Host "  URL"
            if ([string]::IsNullOrWhiteSpace($entry)) { break }
            $raw.Add($entry.Trim())
        }
    }

    return (Test-InputData -RawUrls $raw)
}

#endregion Helper Functions - Input Collection

#region Helper Functions - Web Scanning

function Invoke-PageFetch {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $params = @{
        Uri                = $Url
        TimeoutSec         = $TimeoutSeconds
        UserAgent          = $UserAgent
        ErrorAction        = 'Stop'
        UseBasicParsing    = $true
        MaximumRedirection = 5
    }

    if ($SkipSSLValidation -and $PSVersionTable.PSVersion.Major -ge 7) {
        $params['SkipCertificateCheck'] = $true
    } elseif ($SkipSSLValidation) {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { param($s, $c, $ch, $e) $true }
    }

    $response = Invoke-WebRequest @params
    return [string]$response.Content
}

function Get-LinkedScriptUrls {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[string]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlContent,

        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )

    $urls = [System.Collections.Generic.List[string]]::new()
    $base = [uri]$BaseUrl
    $hits = [regex]::Matches($HtmlContent, '<script[^>]+src\s*=\s*[''"]([^''"]+)[''"]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($m in $hits) {
        $src = $m.Groups[1].Value
        try {
            $resolved = [uri]::new($base, $src)
            $urls.Add($resolved.AbsoluteUri)
        } catch {
            # Unresolvable relative paths are silently skipped
        }
    }
    return $urls
}

function Find-TagsInContent {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$SourceUrl,

        [string]$ContentSource = 'Page HTML'
    )

    $found = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($tagName in $Script:TagSignatures.Keys) {
        $sig  = $Script:TagSignatures[$tagName]
        $hits = [regex]::Matches($Content, $sig.Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($hits.Count -gt 0) {
            $identifiers = ($hits | Select-Object -ExpandProperty Value | Sort-Object -Unique) -join '; '
            $found.Add([PSCustomObject]@{
                ScanTimestamp  = $Script:ScanStart.ToString('yyyy-MM-dd HH:mm:ss')
                SourceUrl      = $SourceUrl
                TagName        = $tagName
                TagIdentifier  = $identifiers
                Category       = $sig.Category
                RiskLevel      = $sig.RiskLevel
                GDPRRelevant   = $sig.GDPRRelevant
                CCPARelevant   = $sig.CCPARelevant
                DataCollected  = $sig.DataCollected
                VendorCountry  = $sig.VendorCountry
                ContentSource  = $ContentSource
                Source         = 'WebScan'
                ApprovedStatus = 'Unknown'
                Notes          = $sig.Notes
            })
        }
    }
    return $found
}

function Invoke-WebScan {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TargetUrls
    )

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $i = 0

    foreach ($url in $TargetUrls) {
        $i++
        Write-Progress -Activity 'Scanning URLs' `
            -Status "[$i/$($TargetUrls.Count)] $url" `
            -PercentComplete (($i / $TargetUrls.Count) * 100)

        try {
            Write-Status "[INFO] Scanning: $url" -Type Info
            $html = Invoke-PageFetch -Url $url

            $pageResults = Find-TagsInContent -Content $html -SourceUrl $url -ContentSource 'Page HTML'
            foreach ($r in $pageResults) { $allResults.Add($r) }

            if ($ScanLinkedScripts) {
                $scriptUrls = Get-LinkedScriptUrls -HtmlContent $html -BaseUrl $url
                Write-Status "  [INFO] Found $($scriptUrls.Count) linked script(s) to scan" -Type Info

                foreach ($scriptUrl in $scriptUrls) {
                    try {
                        if ($DelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $DelayMilliseconds }
                        $scriptContent = Invoke-PageFetch -Url $scriptUrl
                        $scriptResults = Find-TagsInContent -Content $scriptContent -SourceUrl $url -ContentSource "Linked Script: $scriptUrl"
                        foreach ($r in $scriptResults) { $allResults.Add($r) }
                    } catch {
                        Write-Status "  [WARNING] Could not fetch script: $scriptUrl - $($_.Exception.Message)" -Type Warning
                    }
                }
            }

            $tagCount = ($pageResults | Measure-Object).Count
            if ($tagCount -gt 0) {
                Write-Status "  [OK] Found $tagCount tag type(s)" -Type Success
            } else {
                Write-Status "  [INFO] No known tracking tags detected on this page" -Type Info
            }
        } catch {
            Write-Status "[ERROR] Failed to scan $url - $($_.Exception.Message)" -Type Error
            $allResults.Add([PSCustomObject]@{
                ScanTimestamp  = $Script:ScanStart.ToString('yyyy-MM-dd HH:mm:ss')
                SourceUrl      = $url
                TagName        = 'SCAN ERROR'
                TagIdentifier  = 'N/A'
                Category       = 'Error'
                RiskLevel      = 'Unknown'
                GDPRRelevant   = $false
                CCPARelevant   = $false
                DataCollected  = 'N/A'
                VendorCountry  = 'N/A'
                ContentSource  = 'N/A'
                Source         = 'WebScan'
                ApprovedStatus = 'N/A'
                Notes          = $_.Exception.Message
            })
        }

        if ($DelayMilliseconds -gt 0 -and $i -lt $TargetUrls.Count) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    Write-Progress -Activity 'Scanning URLs' -Completed
    return $allResults
}

#endregion Helper Functions - Web Scanning

#region Helper Functions - GTM API

function Invoke-GTMApiRequest {
    # Internal helper - ApiToken is an in-memory string extracted from SecureString
    # and is zeroed immediately after use in Get-GTMApiInventory
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [string]$ApiToken
    )

    $headers  = @{ Authorization = "Bearer $ApiToken" }
    $response = Invoke-RestMethod -Uri $Endpoint -Headers $headers -Method Get -ErrorAction Stop
    return $response
}

function Get-GTMApiInventory {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param()

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $apiBase = 'https://tagmanager.googleapis.com/tagmanager/v2'

    # Securely extract bearer token into memory; zero immediately after use
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BearerToken)
    try {
        $apiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)

        Write-Status "[INFO] Fetching containers for GTM account: $GTMAccountId" -Type Info
        $containersResp = Invoke-GTMApiRequest -Endpoint "$apiBase/accounts/$GTMAccountId/containers" -ApiToken $apiToken
        $containers = @($containersResp.container)
        Write-Status "[OK] Found $($containers.Count) container(s)" -Type Success

        foreach ($container in $containers) {
            Write-Status "  [INFO] Container: $($container.name) ($($container.publicId))" -Type Info

            $workspacesResp = Invoke-GTMApiRequest -Endpoint "$apiBase/$($container.path)/workspaces" -ApiToken $apiToken
            $workspaces     = @($workspacesResp.workspace)

            foreach ($workspace in $workspaces) {
                Write-Status "    [INFO] Workspace: $($workspace.name)" -Type Info
                $contextLabel = "Container: $($container.publicId) / Workspace: $($workspace.name)"

                try {
                    $tagsResp = Invoke-GTMApiRequest -Endpoint "$apiBase/$($workspace.path)/tags" -ApiToken $apiToken
                    foreach ($tag in @($tagsResp.tag)) {
                        if ($null -eq $tag) { continue }
                        $status = if ($tag.paused) { 'PAUSED' } else { 'ACTIVE' }
                        $results.Add([PSCustomObject]@{
                            ScanTimestamp  = $Script:ScanStart.ToString('yyyy-MM-dd HH:mm:ss')
                            SourceUrl      = "GTM Account: $GTMAccountId"
                            TagName        = $tag.name
                            TagIdentifier  = $tag.tagId
                            Category       = $tag.type
                            RiskLevel      = 'Review Required'
                            GDPRRelevant   = $true
                            CCPARelevant   = $true
                            DataCollected  = 'Review tag configuration in GTM'
                            VendorCountry  = 'Review tag type'
                            ContentSource  = $contextLabel
                            Source         = 'GTMApi'
                            ApprovedStatus = 'Unknown'
                            Notes          = "Status: $status; Account: $GTMAccountId"
                        })
                    }
                } catch {
                    Write-Status "    [WARNING] Could not retrieve tags for workspace '$($workspace.name)': $($_.Exception.Message)" -Type Warning
                }
            }
        }
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        Remove-Variable -Name 'apiToken' -ErrorAction SilentlyContinue
    }

    return $results
}

#endregion Helper Functions - GTM API

#region Helper Functions - Baseline and Export

function Set-ApprovedStatus {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[PSCustomObject]]$TagResults,

        [Parameter(Mandatory = $true)]
        [string]$BaselinePath
    )

    $baseline = Import-Csv -Path $BaselinePath
    if (-not ($baseline | Get-Member -Name 'TagName' -MemberType NoteProperty -ErrorAction SilentlyContinue)) {
        throw 'Approved tags baseline CSV must contain a TagName column.'
    }

    $approvedNames = $baseline | Select-Object -ExpandProperty TagName

    foreach ($record in $TagResults) {
        if ($record.TagName -eq 'SCAN ERROR') {
            $record.ApprovedStatus = 'N/A'
        } elseif ($record.TagName -in $approvedNames) {
            $record.ApprovedStatus = 'Approved'
        } else {
            $record.ApprovedStatus = 'UNAPPROVED'
        }
    }
    return $TagResults
}

function Export-TagReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[PSCustomObject]]$Data
    )

    $fileName  = "GTMTagInventory_$Script:Timestamp"
    $directory = if (Test-Path $OutputPath -PathType Container -ErrorAction SilentlyContinue) {
        $OutputPath
    } else {
        Split-Path $OutputPath -Parent
    }

    switch ($OutputFormat) {
        'CSV' {
            $csvFile = Join-Path $directory "$fileName.csv"
            $Data | Export-Csv -Path $csvFile -NoTypeInformation
            Write-Status "[OK] CSV exported: $csvFile" -Type Success
        }
        'Excel' {
            if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                Write-Status '[ERROR] ImportExcel module not found. Install with: Install-Module ImportExcel -Scope CurrentUser' -Type Error
                Write-Status '[INFO] Falling back to CSV export.' -Type Warning
                $csvFile = Join-Path $directory "$fileName.csv"
                $Data | Export-Csv -Path $csvFile -NoTypeInformation
                Write-Status "[OK] CSV exported: $csvFile" -Type Success
                return
            }

            $xlFile = Join-Path $directory "$fileName.xlsx"

            $Data | Export-Excel -Path $xlFile -WorksheetName 'All Tags' `
                -AutoSize -AutoFilter -FreezeTopRow -TableName 'AllTags' -ClearSheet

            $highRisk = $Data | Where-Object { $_.RiskLevel -in @('High', 'Critical') }
            if ($highRisk) {
                $highRisk | Export-Excel -Path $xlFile -WorksheetName 'High Risk' `
                    -AutoSize -AutoFilter -FreezeTopRow -TableName 'HighRiskTags' -Append
            }

            $unapproved = $Data | Where-Object { $_.ApprovedStatus -eq 'UNAPPROVED' }
            if ($unapproved) {
                $unapproved | Export-Excel -Path $xlFile -WorksheetName 'Unapproved Tags' `
                    -AutoSize -AutoFilter -FreezeTopRow -TableName 'UnapprovedTags' -Append
            }

            $adTags = $Data | Where-Object { $_.Category -eq 'Advertising' }
            if ($adTags) {
                $adTags | Export-Excel -Path $xlFile -WorksheetName 'Advertising' `
                    -AutoSize -AutoFilter -FreezeTopRow -TableName 'AdvertisingTags' -Append
            }

            Write-Status "[OK] Excel workbook exported: $xlFile" -Type Success
        }
    }
}

function Write-ScanSummary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Summary banner uses direct Write-Host for formatted console output')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[PSCustomObject]]$Data
    )

    $duration   = (Get-Date) - $Script:ScanStart
    $total      = $Data.Count
    $errors     = ($Data | Where-Object { $_.Category -eq 'Error' }).Count
    $findings   = $Data | Where-Object { $_.Category -ne 'Error' }

    $byRisk     = $findings | Group-Object RiskLevel | Sort-Object Name |
                  Format-Table @{L='Risk Level';E={$_.Name}}, Count -AutoSize | Out-String
    $byCat      = $findings | Group-Object Category  | Sort-Object Name |
                  Format-Table @{L='Category';E={$_.Name}}, Count -AutoSize | Out-String

    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host '  GTM Tag Inventory - Scan Complete' -ForegroundColor Cyan
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host "  Total findings  : $total" -ForegroundColor White
    Write-Host "  Scan duration   : $([int]$duration.TotalSeconds) second(s)" -ForegroundColor White

    if ($errors -gt 0) {
        Write-Host "  Scan errors     : $errors" -ForegroundColor Red
    } else {
        Write-Host "  Scan errors     : $errors" -ForegroundColor White
    }

    Write-Host ''
    Write-Host '  Findings by Risk Level:' -ForegroundColor Yellow
    Write-Host $byRisk -ForegroundColor White
    Write-Host '  Findings by Category:' -ForegroundColor Yellow
    Write-Host $byCat  -ForegroundColor White
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host ''
}

#endregion Helper Functions - Baseline and Export

#region Main Execution

Write-Status '[INFO] Get-GTMTagInventory v1.0 - GRC Tag Audit' -Type Info
Write-Status "[INFO] Scan started: $($Script:ScanStart.ToString('yyyy-MM-dd HH:mm:ss'))" -Type Info

$allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($PSCmdlet.ParameterSetName -eq 'GTMApi') {
    Write-Status '[INFO] Mode: GTM API Inventory' -Type Info
    $apiResults = Get-GTMApiInventory
    foreach ($r in $apiResults) { $allResults.Add($r) }
} else {
    Write-Status '[INFO] Mode: Web Scan' -Type Info
    $targetUrls = Get-TargetUrls

    if ($targetUrls.Count -eq 0) {
        Write-Status '[ERROR] No valid URLs to scan. Exiting.' -Type Error
        exit 1
    }

    Write-Status "[INFO] Scanning $($targetUrls.Count) URL(s)..." -Type Info
    $scanResults = Invoke-WebScan -TargetUrls $targetUrls
    foreach ($r in $scanResults) { $allResults.Add($r) }
}

if (-not [string]::IsNullOrWhiteSpace($ApprovedTagsPath)) {
    Write-Status "[INFO] Applying approved-tag baseline from: $ApprovedTagsPath" -Type Info
    $allResults      = Set-ApprovedStatus -TagResults $allResults -BaselinePath $ApprovedTagsPath
    $unapprovedCount = ($allResults | Where-Object { $_.ApprovedStatus -eq 'UNAPPROVED' }).Count

    if ($unapprovedCount -gt 0) {
        Write-Status "[WARNING] $unapprovedCount unapproved tag(s) detected" -Type Warning
    } else {
        Write-Status '[OK] All detected tags are on the approved list' -Type Success
    }
}

Write-ScanSummary -Data $allResults

if ($OutputFormat -eq 'Object') {
    $allResults
} else {
    Export-TagReport -Data $allResults
}

#endregion Main Execution

#region Cleanup

if ($SkipSSLValidation -and $PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
}

Write-Status '[INFO] Scan complete.' -Type Info

#endregion Cleanup
