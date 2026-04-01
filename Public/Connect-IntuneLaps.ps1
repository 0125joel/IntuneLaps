function Connect-IntuneLaps {
    <#
    .SYNOPSIS
        Authenticates to Microsoft Graph with the scopes required for LAPS retrieval.
    .DESCRIPTION
        Initiates an interactive browser login via Connect-MgGraph requesting the
        minimum scopes for Intune device search and LAPS credential retrieval.
        - DeviceManagementManagedDevices.Read.All  : Search Intune devices
        - DeviceLocalCredential.ReadBasic.All       : Read LAPS metadata
        - DeviceLocalCredential.Read.All            : Read LAPS password (elevated)
        - RoleManagement.Read.Directory             : Read user's own role assignments

        After authentication, constructs a [LapsSession] that evaluates both the API
        scope gate and the Entra role gate to determine the effective permission level.
        Warnings are emitted when access is restricted or PIM activation would help.
    .PARAMETER TenantId
        Optional. The Entra tenant ID or domain to sign in to.
    .OUTPUTS
        [LapsSession]
    .EXAMPLE
        Connect-IntuneLaps
    .EXAMPLE
        Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
    #>
    [CmdletBinding()]
    [OutputType('LapsSession')]
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
            'RoleManagement.Read.Directory'
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

            # Build session singleton (evaluates dual-gate, stores in $script:CurrentSession)
            $Session = Build-LapsSession

            # Surface actionable warnings using the session's own knowledge
            if ($Session.EffectiveLevel -eq [LapsPermissionLevel]::None) {
                [string]$Reason = $Session.GetLimitingGateExplanation([LapsPermissionLevel]::Metadata)
                Write-Warning "No LAPS access after sign-in. $Reason"
            }

            foreach ($Hint in $Session.GetPimUpgradeHints()) {
                Write-Warning $Hint
            }

            if ($Session.HasAuScopedRoles()) {
                foreach ($Au in $Session.AuScopedRoles) {
                    [string]$AuName = if (-not [string]::IsNullOrEmpty($Au.AuDisplayName)) { $Au.AuDisplayName } else { $Au.AuId }
                    Write-Warning "Role '$($Au.RoleName)' is scoped to Administrative Unit '$AuName'. Results may be limited to devices in that unit."
                }
            }

            Write-Verbose "Connected as [$($Session.Account)] — LAPS access level: [$($Session.EffectiveLevel)]"
            return $Session
        }
        catch {
            Write-Error -Message "Failed to connect to Microsoft Graph: $_"
        }
    }
}
