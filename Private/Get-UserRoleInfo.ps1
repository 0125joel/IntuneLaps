function Get-UserRoleInfo {
    <#
    .SYNOPSIS
        Retrieves the signed-in user's active and PIM-eligible Entra roles (best-effort).
    .DESCRIPTION
        Queries Microsoft Graph for the signed-in user's directory role assignments
        (both active and PIM-eligible). Returns a safe empty object on any failure —
        this function is always best-effort and never blocks core LAPS functionality.

        Requires RoleManagement.Read.Directory scope. Returns empty object gracefully
        if this scope is not consented.
    .OUTPUTS
        PSCustomObject with:
            ActiveRoles      [string[]]    - Display names of active Entra roles
            PimEligibleRoles [string[]]    - Display names of PIM-eligible (inactive) roles
            HasPimEligible   [bool]        - Quick flag: $true if any PIM-eligible roles exist
            AuScopedRoles    [hashtable[]] - AU-scoped active roles: @{ RoleName; AuId; AuDisplayName }
            HasAuScopedRoles [bool]        - Quick flag: $true if any AU-scoped roles exist
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Safe empty result returned on any failure
    [PSCustomObject]$EmptyResult = [PSCustomObject]@{
        ActiveRoles        = [string[]]@()
        ActiveRoleIds      = [string[]]@()
        PimEligibleRoles   = [string[]]@()
        PimEligibleRoleIds = [string[]]@()
        HasPimEligible     = $false
        AuScopedRoles      = [hashtable[]]@()
        HasAuScopedRoles   = $false
    }

    try {
        # Step 1: Get the signed-in user's object ID
        $MeResponse = Invoke-MgGraphRequestWithRetry -Parameters @{
            Method = 'GET'
            Uri    = 'https://graph.microsoft.com/v1.0/me?$select=id'
        }
        [string]$UserId = $MeResponse.id
        if ([string]::IsNullOrEmpty($UserId)) {
            Write-Verbose 'Get-UserRoleInfo: Could not retrieve user object ID.'
            return $EmptyResult
        }

        # Step 2: Get active directory role assignments
        [string[]]$ActiveRoleNames = @()
        [string[]]$ActiveRoleIds   = @()
        $AuScopedRolesList = [System.Collections.Generic.List[hashtable]]::new()
        try {
            [string]$ActiveUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$UserId'&`$expand=roleDefinition(`$select=id,displayName)"
            $AllActive = Invoke-MgGraphPagedRequest -Uri $ActiveUri

            if ($AllActive.Count -gt 0) {
                # Collect names and IDs in parallel (same index = same role)
                $ActiveNamesList = [System.Collections.Generic.List[string]]::new()
                $ActiveIdsList   = [System.Collections.Generic.List[string]]::new()
                foreach ($Assignment in $AllActive) {
                    if (-not ($Assignment.roleDefinition -and $Assignment.roleDefinition.displayName)) { continue }
                    $ActiveNamesList.Add($Assignment.roleDefinition.displayName)
                    # Prefer roleDefinition.id (always present via expand) over top-level roleDefinitionId
                    [string]$RoleGuid = if ($Assignment.roleDefinition.id) { $Assignment.roleDefinition.id } else { $Assignment.roleDefinitionId }
                    if ($RoleGuid) { $ActiveIdsList.Add($RoleGuid) }
                }
                $ActiveRoleNames = $ActiveNamesList.ToArray()
                $ActiveRoleIds   = $ActiveIdsList.ToArray()

                # Collect AU-scoped assignments with display name (best-effort lookup per AU)
                foreach ($Assignment in $AllActive) {
                    if (-not ($Assignment.roleDefinition -and $Assignment.roleDefinition.displayName)) { continue }
                    if ($Assignment.directoryScopeId -eq '/') { continue }

                    [string]$AuId          = $Assignment.directoryScopeId
                    [string]$AuDisplayName = ''
                    try {
                        # directoryScopeId for AUs is '/administrativeUnits/<guid>'
                        [string]$AuGuid = $AuId -replace '^/administrativeUnits/', ''
                        $AuResponse = Invoke-MgGraphRequestWithRetry -Parameters @{
                            Method = 'GET'
                            Uri    = "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$AuGuid`?`$select=displayName"
                        }
                        $AuDisplayName = $AuResponse.displayName
                    }
                    catch {
                        Write-Verbose "Get-UserRoleInfo: Could not retrieve AU display name for '$AuId': $_"
                    }

                    $AuScopedRolesList.Add(@{
                        RoleName      = $Assignment.roleDefinition.displayName
                        AuId          = $AuId
                        AuDisplayName = $AuDisplayName
                    })
                }
            }
        }
        catch {
            Write-Verbose "Get-UserRoleInfo: Could not retrieve active roles: $_"
        }

        # Step 3: Get PIM-eligible role assignments
        [string[]]$EligibleRoleNames = @()
        [string[]]$EligibleRoleIds   = @()
        try {
            [string]$EligibleUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$UserId'&`$expand=roleDefinition(`$select=id,displayName)"
            $AllEligible = Invoke-MgGraphPagedRequest -Uri $EligibleUri

            if ($AllEligible.Count -gt 0) {
                $EligibleNamesList = [System.Collections.Generic.List[string]]::new()
                $EligibleIdsList   = [System.Collections.Generic.List[string]]::new()
                foreach ($Instance in $AllEligible) {
                    if (-not ($Instance.roleDefinition -and $Instance.roleDefinition.displayName)) { continue }
                    $EligibleNamesList.Add($Instance.roleDefinition.displayName)
                    [string]$RoleGuid = if ($Instance.roleDefinition.id) { $Instance.roleDefinition.id } else { $Instance.roleDefinitionId }
                    if ($RoleGuid) { $EligibleIdsList.Add($RoleGuid) }
                }
                $EligibleRoleNames = $EligibleNamesList.ToArray()
                $EligibleRoleIds   = $EligibleIdsList.ToArray()
            }
        }
        catch {
            Write-Verbose "Get-UserRoleInfo: Could not retrieve PIM eligible roles: $_"
        }

        [hashtable[]]$AuScopedRolesArray = if ($AuScopedRolesList.Count -gt 0) { $AuScopedRolesList.ToArray() } else { [hashtable[]]@() }

        return [PSCustomObject]@{
            ActiveRoles        = [string[]]$ActiveRoleNames
            ActiveRoleIds      = [string[]]$ActiveRoleIds
            PimEligibleRoles   = [string[]]$EligibleRoleNames
            PimEligibleRoleIds = [string[]]$EligibleRoleIds
            HasPimEligible     = ($EligibleRoleNames.Count -gt 0)
            AuScopedRoles      = $AuScopedRolesArray
            HasAuScopedRoles   = ($AuScopedRolesArray.Count -gt 0)
        }
    }
    catch {
        Write-Verbose "Get-UserRoleInfo: Role lookup failed, returning empty result: $_"
        return $EmptyResult
    }
}
