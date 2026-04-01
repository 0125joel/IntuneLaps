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
        [AllowEmptyString()]
        [string]$DeviceName,

        [Parameter(Mandatory = $false)]
        [switch]$ExactMatch
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $Session = Get-CurrentSession
        $Session.AssertMinimumLevel([LapsPermissionLevel]::Metadata)
    }

    process {
        try {
            # Build OData filter — server-side, Filter-Left principle
            [string]$Filter = ''
            if (-not [string]::IsNullOrWhiteSpace($DeviceName)) {
                [string]$SafeName = $DeviceName -replace "'", "''"
                if ($ExactMatch) {
                    $Filter = "deviceName eq '$SafeName'"
                }
                else {
                    $Filter = "startsWith(deviceName,'$SafeName')"
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
            $AllDevices = Invoke-MgGraphPagedRequest -Uri $NextUri -OnPageLoaded {
                param([int]$Count)
                Write-Progress -Activity 'Find-IntuneLapsDevice' `
                               -Status "Loading devices... ($Count loaded)" `
                               -PercentComplete -1
            }
            Write-Progress -Activity 'Find-IntuneLapsDevice' -Completed

            if ($Session.HasAuScopedRoles()) {
                Write-Warning 'Your role is scoped to one or more Administrative Units. Results may not include all tenant devices.'
            }

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
