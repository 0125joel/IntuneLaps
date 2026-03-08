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
            [byte[]]$DecodedBytes = [System.Convert]::FromBase64String($PasswordBase64)

            # UTF-16LE encodes every ASCII character as two bytes where the high byte is 0x00.
            # Detect this by checking byte[1]: if it is 0x00 the payload is UTF-16LE (documented
            # Windows LAPS format). If not, fall back to UTF-8 (some Intune LAPS configurations).
            [bool]$IsUtf16Le = ($DecodedBytes.Length -ge 2) -and ($DecodedBytes[1] -eq 0)
            [string]$DecodedPassword = if ($IsUtf16Le) {
                [System.Text.Encoding]::Unicode.GetString($DecodedBytes)
            } else {
                [System.Text.Encoding]::UTF8.GetString($DecodedBytes)
            }
            return $DecodedPassword
        }
        catch {
            Write-Error -Message "Failed to decode LAPS password: $_"
            return $null
        }
    }
}
