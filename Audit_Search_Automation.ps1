<#
.SYNOPSIS
Microsoft 365 Unified Audit Log Search and CSV Export
#>

$OutputFolder = Read-Host "Enter the output folder path (press Enter for current folder)"
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = (Get-Location).Path }

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    try { New-Item -Path $OutputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    catch { Write-Host "Unable to create output folder: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Press Enter to close"; exit }
}

function Get-ValidDate($Prompt) {
    while ($true) {
        $InputDate = Read-Host $Prompt
        try { return [datetime]::ParseExact($InputDate,"dd-MM-yyyy",[System.Globalization.CultureInfo]::InvariantCulture).Date }
        catch { Write-Host "Invalid date. Use DD-MM-YYYY, for example 25-08-2026." -ForegroundColor Yellow }
    }
}

$StartDate = Get-ValidDate "Enter Start Date (DD-MM-YYYY)"
$EndDate = Get-ValidDate "Enter End Date (DD-MM-YYYY)"
$EndDate = $EndDate.AddDays(1).AddSeconds(-1)

Write-Host "`nOperation Filter Examples:" -ForegroundColor Cyan
Write-Host "  Press Enter = All operations"
Write-Host "  FileDownloaded"
Write-Host "  FileDeleted"
Write-Host "  FileAccessed"
Write-Host "  MailItemsAccessed"
Write-Host "  Set-Mailbox"
Write-Host "  Add member to group"
Write-Host "For multiple operations, separate with commas."
Write-Host "Example: FileDownloaded,FileDeleted" -ForegroundColor Yellow

$OperationsInput = Read-Host "Enter Operation(s) (press Enter for All)"

$Operations = @()
if (-not [string]::IsNullOrWhiteSpace($OperationsInput)) {
    $Operations = @(
        $OperationsInput -split "," |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

if ($EndDate.Date -lt $StartDate.Date) {
    Write-Host "End Date cannot be earlier than Start Date." -ForegroundColor Red
    Read-Host "Press Enter to close"; exit
}

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    try { Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }
    catch { Write-Host "Module installation failed: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Press Enter to close"; exit }
}

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Write-Host "`nConnecting to Microsoft 365..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    Write-Host "Connected successfully." -ForegroundColor Green
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to close"; exit
}

if (-not (Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue)) {
    Write-Host "Search-UnifiedAuditLog is not available. Check audit permissions and tenant capabilities." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to close"; exit
}

Write-Host "`nSearching Unified Audit Log..." -ForegroundColor Cyan
if ($Operations.Count -eq 0) {
    Write-Host "Operation Filter : All" -ForegroundColor Cyan
}
else {
    Write-Host "Operation Filter : $($Operations -join ', ')" -ForegroundColor Cyan
}

$SessionId = [guid]::NewGuid().ToString()
$AllResults = @()
$ResultSize = 5000
$Page = @()
$PageNumber = 0

try {
    do {
        $Params = @{
            StartDate = $StartDate
            EndDate = $EndDate
            SessionId = $SessionId
            SessionCommand = "ReturnLargeSet"
            ResultSize = $ResultSize
            ErrorAction = "Stop"
        }

        if ($Operations.Count -gt 0) { $Params["Operations"] = $Operations }

        $Page = @(Search-UnifiedAuditLog @Params)
        $PageNumber++
        if ($Page.Count -gt 0) {
            $AllResults += $Page
            Write-Host "Page ${PageNumber}: $($Page.Count) records | Total: $($AllResults.Count)" -ForegroundColor Green
        }
    } while ($Page.Count -eq $ResultSize)
}
catch {
    Write-Host "Audit search failed: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to close"; exit
}

$Inventory = foreach ($Result in $AllResults) {
    $Audit = $null
    try { if ($Result.AuditData) { $Audit = $Result.AuditData | ConvertFrom-Json -ErrorAction Stop } } catch {}

    $Workload = if ($Audit -and $Audit.Workload) { [string]$Audit.Workload } else { "" }
    $ObjectName = ""
    if ($Audit) {
        foreach ($Name in @("ObjectId","SourceFileName","ItemName","SiteUrl","Folder","ResourceUrl","MailboxOwnerUPN")) {
            if ($Audit.PSObject.Properties.Name -contains $Name -and $Audit.$Name) { $ObjectName = [string]$Audit.$Name; break }
        }
    }
    $ClientIP = ""
    if ($Audit) {
        foreach ($Name in @("ClientIP","ClientIPAddress","ClientIp")) {
            if ($Audit.PSObject.Properties.Name -contains $Name -and $Audit.$Name) { $ClientIP = [string]$Audit.$Name; break }
        }
    }

    [PSCustomObject][ordered]@{
        "Creation Date" = $Result.CreationDate
        "User" = $Result.UserIds
        "Operation" = $Result.Operations
        "Record Type" = $Result.RecordType
        "Workload" = $Workload
        "Object" = $ObjectName
        "Client IP" = $ClientIP
        "Audit Data" = $Result.AuditData
    }
}

$Columns = @("Creation Date","User","Operation","Record Type","Workload","Object","Client IP","Audit Data")
$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$CsvPath = Join-Path $OutputFolder "Microsoft365_Audit_Search_$TimeStamp.csv"

try {
    if (@($Inventory).Count -eq 0) {
        Set-Content -Path $CsvPath -Value ('"' + ($Columns -join '","') + '"') -Encoding UTF8
        Write-Host "`nNo audit records found. Header-only CSV created." -ForegroundColor Yellow
    }
    else {
        $Inventory | Select-Object $Columns | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nAudit results exported successfully." -ForegroundColor Green
    }

    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "Audit Search Automation Completed" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Records Found : $($AllResults.Count)"
    Write-Host "CSV File      : $CsvPath"
}
catch { Write-Host "CSV export failed: $($_.Exception.Message)" -ForegroundColor Red }

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Read-Host "`nPress Enter to close this window"
