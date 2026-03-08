function Find-IntuneLapsDevice {
    <#
    .SYNOPSIS
        Searches for Intune-managed devices by name.
    .DESCRIPTION
        Queries the Microsoft Graph API (/deviceManagement/managedDevices) using a
        server-side OData filter. Supports partial name matching with startsWith.
        Returns a structured list of matching devices suitable for piping to
        Get-IntuneLapsCredential.
    .PARAMETER DeviceName
        The device name (or partial name) to search for. Supports wildcards by using
        a prefix — "DESK" will match any device starting with "DESK".
    .PARAMETER ExactMatch
        When specified, requires an exact (case-insensitive) name match instead of
        a startsWith filter.
    .EXAMPLE
        Find-IntuneLapsDevice -DeviceName 'DESKTOP-'
    .EXAMPLE
        Find-IntuneLapsDevice -DeviceName 'WS001' -ExactMatch
    .EXAMPLE
        Find-IntuneLapsDevice -DeviceName 'DESK' | Get-IntuneLapsCredential
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$DeviceName,

        [Parameter(Mandatory = $false)]
        [switch]$ExactMatch
    )

    begin {
        $ErrorActionPreference = 'Stop'

        # Verify we're connected
        try {
            $null = Get-MgContext -ErrorAction Stop
        }
        catch {
            throw 'Not connected. Run Connect-IntuneLaps before searching for devices.'
        }
    }

    process {
        try {
            # Build OData filter — server-side, Filter-Left principle
            [string]$Filter = ''
            if (-not [string]::IsNullOrWhiteSpace($DeviceName)) {
                if ($ExactMatch) {
                    $Filter = "deviceName eq '$DeviceName'"
                }
                else {
                    $Filter = "startsWith(deviceName,'$DeviceName')"
                }
            }

            if ($Filter) {
                Write-Verbose "Querying Graph API with filter: $Filter"
                [hashtable]$QueryParams = @{
                    Method = 'GET'
                    Uri    = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$Filter&`$select=id,deviceName,operatingSystem,osVersion,lastSyncDateTime,managementState,joinType"
                }
            }
            else {
                Write-Verbose 'Querying Graph API for all managed devices (no filter)'
                [hashtable]$QueryParams = @{
                    Method = 'GET'
                    Uri    = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,osVersion,lastSyncDateTime,managementState,joinType"
                }
            }

            $Response = Invoke-MgGraphRequest @QueryParams

            if ($null -eq $Response -or $null -eq $Response.value -or $Response.value.Count -eq 0) {
                if ($DeviceName) {
                    Write-Warning "No Intune-managed devices found matching '$DeviceName'."
                } else {
                    Write-Warning 'No Intune-managed devices found in the tenant.'
                }
                return
            }

            foreach ($Device in $Response.value) {
                [PSCustomObject]@{
                    DeviceId          = $Device.id
                    DeviceName        = $Device.deviceName
                    OperatingSystem   = $Device.operatingSystem
                    OsVersion         = $Device.osVersion
                    ManagementState   = $Device.managementState
                    JoinType          = $Device.joinType
                    LastSyncDateTime  = $Device.lastSyncDateTime
                }
            }
        }
        catch {
            Write-Error -Message "Failed to search for devices: $_"
        }
    }
}
