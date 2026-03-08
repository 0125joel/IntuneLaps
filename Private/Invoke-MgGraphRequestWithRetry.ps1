function Invoke-MgGraphRequestWithRetry {
    <#
    .SYNOPSIS
        Wrapper around Invoke-MgGraphRequest with automatic 429 throttle handling.
    .DESCRIPTION
        Retries the request on HTTP 429 (Too Many Requests) using the Retry-After
        header value or exponential backoff (4s, 8s, 16s). Passes all parameters
        through to Invoke-MgGraphRequest via splatting.
    .PARAMETER Parameters
        Hashtable of parameters to pass to Invoke-MgGraphRequest (e.g. Method, Uri).
    .PARAMETER MaxRetries
        Maximum number of retry attempts after throttling. Default: 3.
    .EXAMPLE
        Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $Uri }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3
    )

    process {
        [int]$Attempt = 0
        while ($true) {
            try {
                return Invoke-MgGraphRequest @Parameters
            }
            catch {
                $Attempt++
                [string]$ErrorText = "$_"
                [bool]$IsThrottled = $ErrorText -match '\b429\b'

                if ($Attempt -ge $MaxRetries -or -not $IsThrottled) {
                    throw
                }

                # Honour Retry-After header; fall back to exponential backoff (4, 8, 16 seconds)
                [int]$WaitSeconds = [Math]::Pow(2, $Attempt) * 2
                if ($_.Exception.PSObject.Properties['Response'] -and $null -ne $_.Exception.Response) {
                    [string]$RetryAfterHeader = $_.Exception.Response.Headers['Retry-After']
                    [int]$ParsedSeconds = 0
                    if (-not [string]::IsNullOrEmpty($RetryAfterHeader) -and [int]::TryParse($RetryAfterHeader, [ref]$ParsedSeconds)) {
                        $WaitSeconds = $ParsedSeconds
                    }
                }

                Write-Warning "Graph API throttled (429). Waiting $WaitSeconds seconds before retry $Attempt/$MaxRetries..."
                Start-Sleep -Seconds $WaitSeconds
            }
        }
    }
}
