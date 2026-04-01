function Disconnect-IntuneLaps {
    <#
    .SYNOPSIS
        Disconnects the current Microsoft Graph session.
    .DESCRIPTION
        A thin wrapper around Disconnect-MgGraph that provides a clean
        user-facing experience consistent with the IntuneLaps module.
    .EXAMPLE
        Disconnect-IntuneLaps
    #>
    [CmdletBinding()]
    param()

    process {
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            $script:CurrentSession = $null
            Write-Verbose 'Disconnected from Microsoft Graph.'
        }
        catch {
            Write-Warning "Could not cleanly disconnect: $_"
        }
    }
}
