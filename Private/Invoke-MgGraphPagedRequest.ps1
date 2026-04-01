function Invoke-MgGraphPagedRequest {
    <#
    .SYNOPSIS
        Executes a paginated Microsoft Graph GET request and returns all results.
    .DESCRIPTION
        Handles @odata.nextLink pagination automatically, collecting all pages into
        a single list. Optionally invokes a scriptblock after each page, passing the
        running item count, to support progress reporting in CLI and GUI contexts.
    .PARAMETER Uri
        The initial Graph API URI to query.
    .PARAMETER OnPageLoaded
        Optional scriptblock invoked after each page is appended. Receives one
        argument: the total number of items collected so far.
    .EXAMPLE
        $Devices = Invoke-MgGraphPagedRequest -Uri $Uri
    .EXAMPLE
        $Devices = Invoke-MgGraphPagedRequest -Uri $Uri -OnPageLoaded {
            param([int]$Count)
            Write-Progress -Activity 'Loading' -Status "$Count loaded" -PercentComplete -1
        }
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [scriptblock]$OnPageLoaded
    )

    process {
        $Results = [System.Collections.Generic.List[object]]::new()
        [string]$NextUri = $Uri
        do {
            $Response = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $NextUri }
            if ($Response.value) {
                foreach ($Item in $Response.value) { $Results.Add($Item) }
            }
            $NextUri = $Response.'@odata.nextLink'
            if ($OnPageLoaded) {
                & $OnPageLoaded $Results.Count
            }
        } while ($NextUri)

        # Comma operator prevents PowerShell from unwrapping the list on return
        return , $Results
    }
}
