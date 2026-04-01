function Get-CurrentSession {
    <#
    .SYNOPSIS
        Returns the active [LapsSession] or throws if not connected.
    .DESCRIPTION
        Private guard function. All public cmdlets call this instead of checking
        Get-MgContext directly. Provides a single, consistent error message when
        the user has not called Connect-IntuneLaps.
    .OUTPUTS
        [LapsSession]
    .EXAMPLE
        $Session = Get-CurrentSession
    #>
    [CmdletBinding()]
    [OutputType([LapsSession])]
    param()

    process {
        if ($null -eq $script:CurrentSession -or -not $script:CurrentSession.Connected) {
            throw 'Not connected. Run Connect-IntuneLaps before using this command.'
        }
        return $script:CurrentSession
    }
}
