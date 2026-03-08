function ConvertFrom-LapsPassword {
    <#
    .SYNOPSIS
        Decodes a Base64-encoded LAPS password from the Microsoft Graph API.
    .DESCRIPTION
        Windows LAPS stores passwords as UTF-16LE Base64. This function decodes
        the passwordBase64 field from the Graph deviceLocalCredentials response.
    .PARAMETER PasswordBase64
        The Base64-encoded password string from the Graph API response.
    .EXAMPLE
        ConvertFrom-LapsPassword -PasswordBase64 'UQBRAEAAZAA4AGYAOABnAFkA'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PasswordBase64
    )

    process {
        try {
            [byte[]]$DecodedBytes     = [System.Convert]::FromBase64String($PasswordBase64)
            [string]$DecodedPassword  = [System.Text.Encoding]::Unicode.GetString($DecodedBytes)
            return $DecodedPassword
        }
        catch {
            Write-Error -Message "Failed to decode LAPS password: $_"
            return $null
        }
    }
}
