function Connect-IntuneLaps {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Graph with the scopes required for LAPS retrieval.
    .DESCRIPTION
        Initiates an interactive browser login via Connect-MgGraph requesting the
        minimum scopes for Intune device search and LAPS credential retrieval.
        - DeviceManagementManagedDevices.Read.All  : Search Intune devices
        - DeviceLocalCredential.ReadBasic.All       : Read LAPS username/metadata
        - DeviceLocalCredential.Read.All            : Read LAPS password (elevated)
    .PARAMETER TenantId
        Optional. The Entra tenant ID or domain to sign in to.
    .EXAMPLE
        Connect-IntuneLaps
    .EXAMPLE
        Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId
    )

    begin {
        $ErrorActionPreference = 'Stop'

        [string[]]$RequiredScopes = @(
            'DeviceManagementManagedDevices.Read.All'
            'DeviceLocalCredential.ReadBasic.All'
            'DeviceLocalCredential.Read.All'
        )
    }

    process {
        try {
            $ConnectParams = @{ Scopes = $RequiredScopes }
            if ($PSBoundParameters.ContainsKey('TenantId')) {
                $ConnectParams['TenantId'] = $TenantId
            }

            Write-Verbose 'Opening Microsoft Sign-In browser window...'
            Connect-MgGraph @ConnectParams

            $Context = Get-MgContext

            [string]$PermissionLevel = Test-LapsPermission

            [PSCustomObject]$Result = [PSCustomObject]@{
                Account         = $Context.Account
                TenantId        = $Context.TenantId
                Scopes          = $Context.Scopes
                PermissionLevel = $PermissionLevel
                Connected       = $true
            }

            Write-Verbose "Connected as [$($Context.Account)] - LAPS access level: [$PermissionLevel]"
            return $Result
        }
        catch {
            Write-Error -Message "Failed to connect to Microsoft Graph: $_"
        }
    }
}
