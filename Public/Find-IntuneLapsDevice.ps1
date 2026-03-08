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

            [string]$SelectFields = 'id,azureADDeviceId,deviceName,operatingSystem,osVersion,lastSyncDateTime,managementState'
            if ($Filter) {
                Write-Verbose "Querying Graph API with filter: $Filter"
                [string]$NextUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$Filter&`$select=$SelectFields"
            }
            else {
                Write-Verbose 'Querying Graph API for all managed devices (no filter)'
                [string]$NextUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$SelectFields"
            }

            # Paginate through all results via @odata.nextLink (Graph caps at 100 items per page)
            $AllDevices = [System.Collections.Generic.List[object]]::new()
            do {
                $Response = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $NextUri }
                if ($Response.value) {
                    foreach ($Device in $Response.value) { $AllDevices.Add($Device) }
                }
                $NextUri = $Response.'@odata.nextLink'
            } while ($NextUri)

            if ($AllDevices.Count -eq 0) {
                if ($DeviceName) {
                    Write-Warning "No Intune-managed devices found matching '$DeviceName'."
                } else {
                    Write-Warning 'No Intune-managed devices found in the tenant.'
                }
                return
            }

            foreach ($Device in $AllDevices) {
                [PSCustomObject]@{
                    DeviceId          = $Device.azureADDeviceId
                    IntuneDeviceId    = $Device.id
                    DeviceName        = $Device.deviceName
                    OperatingSystem   = $Device.operatingSystem
                    OsVersion         = $Device.osVersion
                    ManagementState   = $Device.managementState
                    LastSyncDateTime  = $Device.lastSyncDateTime
                }
            }
        }
        catch {
            Write-Error -Message "Failed to search for devices: $_"
        }
    }
}
