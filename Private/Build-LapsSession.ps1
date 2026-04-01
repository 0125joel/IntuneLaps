function Build-LapsSession {
    <#
    .SYNOPSIS
        Builds a [LapsSession] from the current Graph context without re-authenticating.
    .DESCRIPTION
        Private function. Calls Get-MgContext (never Connect-MgGraph), calls Get-UserRoleInfo,
        constructs [LapsSession], stores it in $script:CurrentSession, and returns it.

        Called by Connect-IntuneLaps after authentication completes, and by Show-IntuneLapsGui
        on its STA thread to reconstitute session state without opening a browser (each WPF
        STA thread gets its own module scope — $script:CurrentSession does not carry over).
    .OUTPUTS
        [LapsSession]
    .EXAMPLE
        $Session = Build-LapsSession
    #>
    [CmdletBinding()]
    [OutputType('LapsSession')]
    param()

    process {
        $ErrorActionPreference = 'Stop'

        $Context = Get-MgContext
        if ($null -eq $Context) {
            throw 'No active Microsoft Graph session. Run Connect-IntuneLaps first.'
        }

        [string[]]$Scopes = $Context.Scopes
        $RoleInfo = Get-UserRoleInfo   # Best-effort; returns safe empty object on failure

        $Session = [LapsSession]::new($Context, $Scopes, $RoleInfo)
        $script:CurrentSession = $Session

        return $Session
    }
}
