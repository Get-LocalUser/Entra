<#
.NOTES
    - Requires Microsoft.Graph.Beta module installed (will auto-install if missing).
    - CSV must contain a column named "Device Name".
    - Recommend installing Microsoft.Graph.Beta module with -Verbose on its own outside the script for best results.

    Author:       Get-LocalUser
    Last Updated: 05/2026

.SYNOPSIS
    EntraID Device Lookup Script - Searches for device records in Entra ID.

.DESCRIPTION
    This script allows administrators to search for one or more devices by name
    across Entra ID using Get-MgBetaDevice.

    You can run the script interactively, pass a single device name as a parameter,
    or provide a CSV file for bulk searching. Bulk results are exported to a CSV
    file in your Downloads folder.

.FUNCTIONALITY
    - Imports and verifies the Microsoft.Graph.Beta module.
    - Connects to Microsoft Graph ('Device.Read.All' scope required).
    - Searches for devices in Entra ID by DisplayName.
    - Outputs DisplayName, ID, AccountEnabled, RegisteredDateTime, and LastSignIn.
    - Exports bulk results to CSV in the user's Downloads folder.

.EXAMPLE
    - Run the script via F5 to load functions.
    - Run Find-EntraDevice to display both options.
    - Run Search-SingleEntraDevice for a single device lookup.
    - Run Search-BulkEntraDevices to look up multiple devices from CSV.

#>

# ------------------------ Module Initialization ------------------------
function Initialize-Modules {
    if ($Global:EntraDeviceScriptInitialized) {
        Write-Host "Modules already initialized. Skipping module checks." -ForegroundColor Green
        return
    }

    if (-not (Get-InstalledModule -Name Microsoft.Graph.Beta -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Microsoft.Graph.Beta module. This may take a few minutes..." -ForegroundColor Yellow
        Install-Module -Name Microsoft.Graph.Beta -Scope CurrentUser -Force -Verbose
    }
    Import-Module Microsoft.Graph.Beta -ErrorAction Ignore
    Write-Host "Microsoft.Graph.Beta module imported successfully." -ForegroundColor Yellow

    Connect-MgGraph -Scopes "Device.Read.All" -NoWelcome

    $Global:EntraDeviceScriptInitialized = $true
    Write-Host "Modules initialized." -ForegroundColor Yellow
}

# ------------------------------ Single Device Search ------------------------------
function Search-SingleEntraDevice {
    param([string]$DeviceName)

    if (-not $DeviceName) {
        $DeviceName = Read-Host "Enter the device name to search for"
    }

    if ([string]::IsNullOrWhiteSpace($DeviceName)) {
        Write-Host "No device name provided. Exiting." -ForegroundColor Red
        return
    }

    Write-Host "Searching Entra ID for '$DeviceName'..." -ForegroundColor Yellow

    try {
        $EntraResults = Get-MgBetaDevice `
            -Filter "displayName eq '$DeviceName'" `
            -Property "displayName,id,accountEnabled,RegistrationDateTime,approximateLastSignInDateTime" `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Error querying Entra ID: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    if (-not $EntraResults) {
        Write-Host "No device found in Entra ID for: $DeviceName" -ForegroundColor Red

        return [PSCustomObject]@{
            DisplayName          = $DeviceName
            ID                   = "Not Found"
            AccountEnabled       = "Not Found"
            RegistrationDateTime = "Not Found"
            LastSignIn           = "Not Found"
        }
    }

    if ($EntraResults.Count -gt 1) {
        Write-Host "Multiple devices found for '$DeviceName'. Verify entries before taking action." -ForegroundColor Red
    }
    else {
        Write-Host "Device found in Entra ID." -ForegroundColor Green
    }

    $results = foreach ($device in $EntraResults) {
        [PSCustomObject]@{
            DisplayName          = $device.DisplayName
            ID                   = $device.Id
            AccountEnabled       = $device.AccountEnabled
            RegistrationDateTime = $device.RegistrationDateTime
            LastSignIn           = $device.ApproximateLastSignInDateTime
        }
    }

    # $results | Format-Table -AutoSize
    return $results
}

# ------------------------------ Bulk Device Search ------------------------------
function Search-BulkEntraDevices {
    param([string]$CsvPath)

    if (-not (Test-Path $CsvPath)) {
        Write-Host "CSV file not found: $CsvPath" -ForegroundColor Red
        return
    }

    try {
        $devices    = Import-Csv $CsvPath
        $total      = $devices.Count
        Write-Host "`nProcessing $total devices from CSV..." -ForegroundColor Yellow

        $allResults = @()
        $counter    = 0

        foreach ($row in $devices) {
            $counter++
            $DeviceName = $row.'displayName'

            if ([string]::IsNullOrWhiteSpace($DeviceName)) {
                Write-Host "[$counter/$total] Skipping empty device name." -ForegroundColor Yellow
                continue
            }

            Write-Host "[$counter/$total] Searching: $DeviceName" -ForegroundColor Cyan

            try {
                $EntraResults = Get-MgBetaDevice `
                    -Filter "displayName eq '$DeviceName'" `
                    -Property "displayName,id,accountEnabled,RegistrationDateTime,approximateLastSignInDateTime" `
                    -ErrorAction Stop
            }
            catch {
                Write-Host "  Error querying '$DeviceName': $($_.Exception.Message)" -ForegroundColor Red
                $allResults += [PSCustomObject]@{
                    DisplayName          = $DeviceName
                    ID                   = "Error"
                    AccountEnabled       = "Error"
                    RegistrationDateTime = "Error"
                    LastSignIn           = "Error"
                }
                continue
            }

            if (-not $EntraResults) {
                $allResults += [PSCustomObject]@{
                    DisplayName          = $DeviceName
                    ID                   = "Not Found"
                    AccountEnabled       = "Not Found"
                    RegistrationDateTime = "Not Found"
                    LastSignIn           = "Not Found"
                }
            }
            elseif ($EntraResults.Count -gt 1) {
                Write-Host "  Multiple records found for '$DeviceName'. All entries included in export." -ForegroundColor Red
                foreach ($device in $EntraResults) {
                    $allResults += [PSCustomObject]@{
                        DisplayName          = $device.DisplayName
                        ID                   = $device.Id
                        AccountEnabled       = $device.AccountEnabled
                        RegistrationDateTime = $device.RegistrationDateTime
                        LastSignIn           = $device.ApproximateLastSignInDateTime
                    }
                }
            }
            else {
                $allResults += [PSCustomObject]@{
                    DisplayName          = $EntraResults.DisplayName
                    ID                   = $EntraResults.Id
                    AccountEnabled       = $EntraResults.AccountEnabled
                    RegistrationDateTime = $EntraResults.RegistrationDateTime
                    LastSignIn           = $EntraResults.ApproximateLastSignInDateTime
                }
            }
        }
    }
    catch {
        Write-Host "Error processing CSV: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $Pathway    = "C:\Users\$env:USERNAME\Downloads\"
    $ExportFile = Join-Path -Path $Pathway -ChildPath "EntraDevicesFound.csv"

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
function Find-EntraDevice {
    Write-Host "`nSelect Search Mode:" -ForegroundColor Cyan
    Write-Host "1. Search Single Device"
    Write-Host "2. Search Bulk from CSV"
    $choice = Read-Host "Enter your choice (1 or 2)"

    switch ($choice) {
        "1" {
            Search-SingleEntraDevice
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
                $allResults = Search-BulkEntraDevices -CsvPath $csvPath
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
Find-EntraDevice