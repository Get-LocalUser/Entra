<#
.NOTES
    - Requires Microsoft.Graph.Beta module installed (will auto-install if missing).
    - CSV must contain a column named "Device ID".
    - Requires Device.ReadWrite.All scope to delete devices.
    - Recommend installing Microsoft.Graph.Beta module with -Verbose on its own outside the script for best results.

    Author:       Get-LocalUser
    Last Updated: 05/2026

.SYNOPSIS
    EntraID Device Removal Script - Finds and removes device records from Entra ID by Device ID.

.DESCRIPTION
    This script allows administrators to remove one or more devices by Device ID
    from Entra ID. Supports single and bulk (CSV) removal.

    A confirmation prompt is shown before any deletion. Bulk results are exported
    to a CSV in your Downloads folder showing what was and wasn't removed.

.FUNCTIONALITY
    - Imports and verifies the Microsoft.Graph.Beta module.
    - Connects to Microsoft Graph ('Device.ReadWrite.All' scope required).
    - Looks up and removes devices in Entra ID strictly by Device ID.
    - Prompts for confirmation before deleting.
    - Exports bulk results to CSV in the user's Downloads folder.

.EXAMPLE
    - Run the script via F5 to load functions.
    - Run Remove-EntraDevice to display both options.
    - Run Remove-SingleEntraDevice for a single device removal.
    - Run Remove-BulkEntraDevices to remove multiple devices from CSV.

#>

# ------------------------ Module Initialization ------------------------
function Initialize-Modules {
    if ($Global:EntraDeviceRemovalInitialized) {
        Write-Host "Modules already initialized. Skipping module checks." -ForegroundColor Green
        return
    }

    if (-not (Get-InstalledModule -Name Microsoft.Graph.Beta -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Microsoft.Graph.Beta module. This may take a few minutes..." -ForegroundColor Yellow
        Install-Module -Name Microsoft.Graph.Beta -Scope CurrentUser -Force -Verbose
    }
    Import-Module Microsoft.Graph.Beta -ErrorAction Ignore
    Write-Host "Microsoft.Graph.Beta module imported successfully." -ForegroundColor Yellow

    Connect-MgGraph -Scopes "Device.ReadWrite.All" -NoWelcome

    $Global:EntraDeviceRemovalInitialized = $true
    Write-Host "Modules initialized." -ForegroundColor Yellow
}

# ------------------------------ Single Device Removal ------------------------------
function Remove-SingleEntraDevice {
    param([string]$DeviceId)

    if (-not $DeviceId) {
        $DeviceId = Read-Host "Enter the Device ID to remove"
    }

    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        Write-Host "No Device ID provided. Exiting." -ForegroundColor Red
        return
    }

    Write-Host "Looking up Device ID '$DeviceId' in Entra ID..." -ForegroundColor Yellow

    try {
        $device = Get-MgBetaDevice `
            -DeviceId $DeviceId `
            -Property "displayName,id,accountEnabled,registeredDateTime,approximateLastSignInDateTime" `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Device ID '$DeviceId' not found or error querying Entra ID: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $preview = [PSCustomObject]@{
        DisplayName        = $device.DisplayName
        ID                 = $device.Id
        AccountEnabled     = $device.AccountEnabled
        RegisteredDateTime = $device.RegisteredDateTime
        LastSignIn         = $device.ApproximateLastSignInDateTime
    }

    Write-Host "`nDevice found:" -ForegroundColor Yellow
    $preview | Format-Table -AutoSize

    $confirm = Read-Host "Are you sure you want to delete this device? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        return
    }

    try {
        Remove-MgBetaDevice -DeviceId $DeviceId -ErrorAction Stop
        Write-Host "Device '$($device.DisplayName)' successfully removed from Entra ID." -ForegroundColor Green
    }
    catch {
        Write-Host "Error deleting device '$($device.DisplayName)': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ------------------------------ Bulk Device Removal ------------------------------
function Remove-BulkEntraDevices {
    param([string]$CsvPath)

    if (-not (Test-Path $CsvPath)) {
        Write-Host "CSV file not found: $CsvPath" -ForegroundColor Red
        return
    }

    try {
        $devices = Import-Csv $CsvPath
        $total   = $devices.Count
        Write-Host "`nProcessing $total devices from CSV..." -ForegroundColor Yellow

        Write-Host "`nWARNING: This will attempt to delete $total device(s) from Entra ID." -ForegroundColor Red
        $confirm = Read-Host "Type 'yes' to proceed with bulk deletion"
        if ($confirm -ne "yes") {
            Write-Host "Bulk deletion cancelled." -ForegroundColor Yellow
            return
        }

        $allResults = @()
        $counter    = 0

        foreach ($row in $devices) {
            $counter++
            $DeviceId = $row.'Id'

            if ([string]::IsNullOrWhiteSpace($DeviceId)) {
                Write-Host "[$counter/$total] Skipping empty Device ID." -ForegroundColor Yellow
                continue
            }

            Write-Host "[$counter/$total] Looking up Device ID: $DeviceId" -ForegroundColor Cyan

            try {
                $device = Get-MgBetaDevice `
                    -DeviceId $DeviceId `
                    -Property "displayName,id,accountEnabled,registeredDateTime,approximateLastSignInDateTime" `
                    -ErrorAction Stop
            }
            catch {
                Write-Host "  Not found or error for Device ID '$DeviceId': $($_.Exception.Message)" -ForegroundColor Red
                $allResults += [PSCustomObject]@{
                    DisplayName        = "Not Found"
                    ID                 = $DeviceId
                    AccountEnabled     = "Not Found"
                    RegisteredDateTime = "Not Found"
                    LastSignIn         = "Not Found"
                    Removed            = "Not Found"
                }
                continue
            }

            try {
                Remove-MgBetaDevice -DeviceId $DeviceId -ErrorAction Stop
                Write-Host "  Removed: $($device.DisplayName)" -ForegroundColor Green
                $allResults += [PSCustomObject]@{
                    DisplayName        = $device.DisplayName
                    ID                 = $device.Id
                    AccountEnabled     = $device.AccountEnabled
                    RegisteredDateTime = $device.RegisteredDateTime
                    LastSignIn         = $device.ApproximateLastSignInDateTime
                    Removed            = "✓"
                }
            }
            catch {
                Write-Host "  Error deleting '$($device.DisplayName)': $($_.Exception.Message)" -ForegroundColor Red
                $allResults += [PSCustomObject]@{
                    DisplayName        = $device.DisplayName
                    ID                 = $device.Id
                    AccountEnabled     = $device.AccountEnabled
                    RegisteredDateTime = $device.RegisteredDateTime
                    LastSignIn         = $device.ApproximateLastSignInDateTime
                    Removed            = "Failed"
                }
            }
        }
    }
    catch {
        Write-Host "Error processing CSV: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $Pathway    = "C:\Users\$env:USERNAME\Downloads\"
    $ExportFile = Join-Path -Path $Pathway -ChildPath "EntraDevicesRemoved.csv"

    if ($allResults) {
        $Utf8WithBom = New-Object System.Text.UTF8Encoding $true
        $csvContent  = $allResults | ConvertTo-Csv -NoTypeInformation | Out-String
        [System.IO.File]::WriteAllText($ExportFile, $csvContent, $Utf8WithBom)

        Write-Host "`nResults exported to: $ExportFile" -ForegroundColor Yellow
        Write-Host "Open in Excel for best visual." -ForegroundColor Magenta
    }
    else {
        Write-Host "No results to export." -ForegroundColor Yellow
    }

    return $allResults
}

# ------------------------------ Interactive Menu ------------------------------
function Remove-EntraDevice {
    Write-Host "`nSelect Removal Mode:" -ForegroundColor Cyan
    Write-Host "1. Remove Single Device"
    Write-Host "2. Remove Bulk from CSV"
    $choice = Read-Host "Enter your choice (1 or 2)"

    switch ($choice) {
        "1" {
            Remove-SingleEntraDevice
        }
        "2" {
            Add-Type -AssemblyName System.Windows.Forms

            $form               = New-Object System.Windows.Forms.Form
            $form.TopMost       = $true
            $form.WindowState   = 'Minimized'
            $form.ShowInTaskbar = $false

            $openFileDialog                  = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter           = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
            $openFileDialog.Title            = "Select the CSV file"
            $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

            if ($openFileDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
                $csvPath    = $openFileDialog.FileName
                $allResults = Remove-BulkEntraDevices -CsvPath $csvPath
                $allResults | Format-Table -AutoSize
            }
            else {
                Write-Host "No file selected. Exiting." -ForegroundColor Red
            }

            $form.Dispose()
        }
        default {
            Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
        }
    }
}

# ------------------------------ Main Execution ------------------------------
Initialize-Modules
Remove-EntraDevice