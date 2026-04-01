function Get-IntuneLapsCredential {
    <#
    .SYNOPSIS
        Retrieves LAPS local admin credentials for an Intune-managed device.
    .DESCRIPTION
        Calls the Microsoft Graph API endpoint:
            GET /directory/deviceLocalCredentials/{deviceId}
        Always fetches device metadata (deviceName, backup timestamps).

        When the current session has Full permission level, also fetches the full
        credentials array containing all local admin accounts and their passwords.
        All accounts are returned (sorted newest-first by backup date).

        When the session has Metadata level, only metadata is returned and a warning
        explains which gate is limiting access (scope or role).

        Use Connect-IntuneLaps to establish a session. The session's EffectiveLevel
        determines what is returned — there is no -IncludePassword parameter.
    .PARAMETER DeviceId
        The Entra device object ID (GUID). Accepts pipeline input from Find-IntuneLapsDevice.
    .PARAMETER DeviceName
        Device name or prefix to search for. Internally calls Find-IntuneLapsDevice and
        retrieves credentials for each matching device. Use -ExactMatch for an exact name.
    .PARAMETER ExactMatch
        When used with -DeviceName, requires an exact (case-insensitive) name match.
    .EXAMPLE
        Get-IntuneLapsCredential -DeviceId 'b465e4e8-e4e8-b465-e8e4-65b4e8e465b4'
    .EXAMPLE
        Get-IntuneLapsCredential -DeviceName 'DESKTOP-001' -ExactMatch
    .EXAMPLE
        Get-IntuneLapsCredential -DeviceName 'DESKTOP-'
    .EXAMPLE
        Find-IntuneLapsDevice -DeviceName 'WS001' | Get-IntuneLapsCredential
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDeviceId')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ByDeviceId', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceId,

        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $false)]
        [switch]$ExactMatch
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $Session = Get-CurrentSession
        $Session.AssertMinimumLevel([LapsPermissionLevel]::Metadata)
    }

    process {
        # Resolve -DeviceName to a list of device IDs via Find-IntuneLapsDevice
        [string[]]$ResolvedIds = if ($PSCmdlet.ParameterSetName -eq 'ByDeviceName') {
            $Found = Find-IntuneLapsDevice -DeviceName $DeviceName -ExactMatch:$ExactMatch
            if (-not $Found) { return }
            @($Found | ForEach-Object { $_.DeviceId })
        } else {
            @($DeviceId)
        }

        foreach ($ResolvedId in $ResolvedIds) {
            try {
                # Step 1: Always fetch metadata (no $select=credentials — avoids unnecessary privilege)
                [string]$MetadataUri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$ResolvedId"
                Write-Verbose "Fetching LAPS metadata for device: $ResolvedId"
                $MetadataResponse = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $MetadataUri }

                $Result = [PSCustomObject]@{
                    DeviceId           = $ResolvedId
                    DeviceName         = $MetadataResponse.deviceName
                    LastBackupDateTime = $MetadataResponse.lastBackupDateTime
                    RefreshDateTime    = $MetadataResponse.refreshDateTime
                    IsPasswordExpired  = if ($MetadataResponse.refreshDateTime) { [datetime]$MetadataResponse.refreshDateTime -lt (Get-Date) } else { $null }
                    EffectiveLevel     = $Session.EffectiveLevel
                    Credentials        = $null   # [PSCustomObject[]] when Full; $null when Metadata
                }

                # Step 2: Fetch credentials array only when session has Full access
                if ($Session.CanRetrievePasswords()) {
                    Write-Verbose 'Session has Full access — requesting credentials array...'
                    [string]$CredUri = 'https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/' + $ResolvedId + '?$select=id,credentials'

                    try {
                        $CredResponse = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $CredUri }

                        if ($CredResponse.credentials -and $CredResponse.credentials.Count -gt 0) {
                            # Return ALL accounts, sorted newest-first by backup date
                            $Result.Credentials = @(
                                $CredResponse.credentials |
                                Sort-Object { [datetime]$_.backupDateTime } -Descending |
                                ForEach-Object {
                                    [PSCustomObject]@{
                                        AccountName    = $_.accountName
                                        AccountSid     = $_.accountSid
                                        Password       = ConvertFrom-LapsPassword -PasswordBase64 $_.passwordBase64
                                        BackupDateTime = $_.backupDateTime
                                    }
                                }
                            )
                        }
                        # If credentials array is empty: device has a LAPS record but no credential entries yet
                    }
                    catch {
                        [int]$HttpStatus = 0
                        if ($_.Exception.PSObject.Properties['Response'] -and $null -ne $_.Exception.Response) {
                            $HttpStatus = [int]$_.Exception.Response.StatusCode
                        }
                        [bool]$Is403 = ($HttpStatus -eq 403) -or ($HttpStatus -eq 0 -and "$_" -match '\b403\b')

                        if ($Is403) {
                            [string]$AuHint = if ($Session.HasAuScopedRoles()) {
                                " Your role is AU-scoped — device '$($Result.DeviceName)' may be outside your Administrative Unit."
                            } else { '' }
                            Write-Warning "Credential retrieval returned 403 for device '$($Result.DeviceName)'. Effective level is '$($Session.EffectiveLevel)' but Graph denied access.$AuHint"
                        }
                        else {
                            Write-Error "Failed to retrieve LAPS credentials for device '$($Result.DeviceName)': $_"
                        }
                    }
                }
                else {
                    # Metadata-level session: explain why and provide actionable hints
                    [string]$Explanation = $Session.GetLimitingGateExplanation([LapsPermissionLevel]::Full)
                    Write-Warning "Metadata only — credentials not retrieved. $Explanation"

                    foreach ($Hint in $Session.GetPimUpgradeHints()) {
                        Write-Warning $Hint
                    }
                }

                $Result
            }
            catch {
                [int]$HttpStatus = 0
                if ($_.Exception.PSObject.Properties['Response'] -and $null -ne $_.Exception.Response) {
                    $HttpStatus = [int]$_.Exception.Response.StatusCode
                }
                [bool]$IsNotFound = ($HttpStatus -eq 404) -or
                                    ($HttpStatus -eq 400 -and "$_" -match 'could not be found') -or
                                    ($HttpStatus -eq 0 -and ("$_" -match '\b404\b' -or ("$_" -match '\b400\b' -and "$_" -match 'could not be found')))
                if ($IsNotFound) {
                    Write-Warning "No LAPS credential record found for device '$ResolvedId'. Ensure LAPS is configured and the device has checked in recently."
                }
                else {
                    Write-Error "Failed to retrieve LAPS credential for device '$ResolvedId': $_"
                }
            }
        }
    }
}
