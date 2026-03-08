function Test-LapsPermission {
    <#
    .SYNOPSIS
        Checks the current Graph session for LAPS-related permission levels.
    .DESCRIPTION
        Inspects the scopes granted in the current Microsoft Graph context to
        determine whether the user can read only metadata or also the full
        password. Returns a string: 'Full', 'Metadata', or 'None'.
    .OUTPUTS
        [string] 'Full' | 'Metadata' | 'None'
    .EXAMPLE
        $Level = Test-LapsPermission
        if ($Level -eq 'Full') { ... }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    process {
        try {
            $Context = Get-MgContext -ErrorAction Stop
        }
        catch {
            Write-Warning 'Not connected to Microsoft Graph. Run Connect-IntuneLaps first.'
            return 'None'
        }

        if ($null -eq $Context) {
            return 'None'
        }

        [string[]]$Scopes = $Context.Scopes

        # Full password access requires DeviceLocalCredential.Read.All
        if ($Scopes -contains 'DeviceLocalCredential.Read.All') {
            return 'Full'
        }

        # Metadata-only access via ReadBasic
        if ($Scopes -contains 'DeviceLocalCredential.ReadBasic.All') {
            return 'Metadata'
        }

        return 'None'
    }
}
