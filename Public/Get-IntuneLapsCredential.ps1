function Get-IntuneLapsCredential {
    <#
    .SYNOPSIS
        Retrieves LAPS local admin credentials for an Intune-managed device.
    .DESCRIPTION
        Calls the Microsoft Graph API endpoint:
            GET /directory/deviceLocalCredentials/{deviceId}
        Without -IncludePassword: returns account name and metadata only.
        With -IncludePassword: returns the decoded plain-text password as well.

        Password access requires the Cloud Device Administrator or
        Intune Administrator Entra role plus DeviceLocalCredential.Read.All scope.
        Metadata-only access requires Helpdesk Administrator (or higher) plus
        DeviceLocalCredential.ReadBasic.All scope.
    .PARAMETER DeviceId
        The Intune/Entra device object ID (GUID). Accepts pipeline from Find-IntuneLapsDevice.
    .PARAMETER IncludePassword
        When specified, requests the password from Graph ($select=credentials).
        Will fail with a clear error if the signed-in user lacks sufficient permissions.
    .EXAMPLE
        Get-IntuneLapsCredential -DeviceId 'b465e4e8-e4e8-b465-e8e4-65b4e8e465b4'
    .EXAMPLE
        Get-IntuneLapsCredential -DeviceId 'b465e4e8-e4e8-b465-e8e4-65b4e8e465b4' -IncludePassword
    .EXAMPLE
        Find-IntuneLapsDevice -DeviceName 'WS001' | Get-IntuneLapsCredential -IncludePassword
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePassword
    )

    begin {
        $ErrorActionPreference = 'Stop'

        try {
            $null = Get-MgContext -ErrorAction Stop
        }
        catch {
            throw 'Not connected. Run Connect-IntuneLaps before retrieving credentials.'
        }
    }

    process {
        try {
            # --- Step 1: Always fetch metadata first (no password) ---
            [string]$MetadataUri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$DeviceId"

            Write-Verbose "Fetching LAPS metadata for device: $DeviceId"
            $MetadataResponse = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $MetadataUri }

            [string]$DeviceName       = $MetadataResponse.deviceName
            [string]$LastBackup       = $MetadataResponse.lastBackupDateTime
            [string]$RefreshDateTime  = $MetadataResponse.refreshDateTime

            # --- Step 2: Fetch credentials only if -IncludePassword is requested ---
            [string]$AccountName = $null
            [string]$Password    = $null
            [bool]$PasswordRetrieved = $false

            if ($IncludePassword) {
                Write-Verbose 'Requesting LAPS password (requires elevated permissions)...'

                [string]$PasswordUri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$DeviceId" + '?%24select=id,credentials'

                try {
                    $CredResponse = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $PasswordUri }

                    if ($CredResponse.credentials -and $CredResponse.credentials.Count -gt 0) {
                        # Return the most recent credential (first entry = latest backup)
                        $LatestCred  = $CredResponse.credentials | Sort-Object backupDateTime -Descending | Select-Object -First 1
                        $AccountName = $LatestCred.accountName
                        $Password    = ConvertFrom-LapsPassword -PasswordBase64 $LatestCred.passwordBase64
                        $PasswordRetrieved = $true
                    }
                }
                catch {
                    # HTTP 403 = insufficient permissions — surface a clean message, don't crash
                    if ("$_" -match '\b403\b') {
                        Write-Warning "Insufficient permissions to retrieve the LAPS password for device '$DeviceName'. Your account requires the 'Cloud Device Administrator' or 'Intune Administrator' Entra role."
                    }
                    else {
                        Write-Error "Failed to retrieve LAPS password for device '$DeviceName': $_"
                    }
                }
            }
            else {
                # Metadata-only: accountName is not returned without $select=credentials
                $AccountName = '(Requires elevated permission to view)'
            }

            [PSCustomObject]@{
                DeviceId          = $DeviceId
                DeviceName        = $DeviceName
                AccountName       = $AccountName
                Password          = $Password
                PasswordRetrieved = $PasswordRetrieved
                LastBackupDateTime = $LastBackup
                RefreshDateTime   = $RefreshDateTime
            }
        }
        catch {
            # 404 or 400 "could not be found" = device has no LAPS record in this tenant
            if ("$_" -match '\b404\b' -or ("$_" -match '\b400\b' -and "$_" -match 'could not be found')) {
                Write-Warning "No LAPS credential record found for device '$DeviceId'. Ensure LAPS is configured and the device has checked in recently."
            }
            else {
                Write-Error "Failed to retrieve LAPS credential for device '$DeviceId': $_"
            }
        }
    }
}
