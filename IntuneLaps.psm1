#Requires -Version 5.1

<#
.SYNOPSIS
    IntuneLaps root module loader.
.DESCRIPTION
    Dot-sources all Public and Private function files and exports Public functions.
    Automatically installs Microsoft.Graph.Authentication if not present.
#>

# ─── Permission model types ───────────────────────────────────────────────────
# IMPORTANT: Defined directly in .psm1, NOT in dot-sourced files.
# PowerShell 5.1 and 7 both require types to live in the root .psm1 so that
# callers can reference them (e.g. [LapsPermissionLevel]::Full) without
# needing 'using module'. Dot-sourced class files would lose type accessibility.

enum LapsPermissionLevel {
    None     = 0
    Metadata = 1
    Full     = 2
}

class LapsSession {

    # ── Public properties ────────────────────────────────────────────────────
    [string]              $Account
    [string]              $TenantId
    [bool]                $Connected
    [LapsPermissionLevel] $EffectiveLevel
    [string[]]            $ActiveRoles
    [string[]]            $PimEligibleRoles
    [hashtable[]]         $AuScopedRoles     # @{ RoleName; AuId; AuDisplayName }

    # ── Internal gate results (hidden but accessible via direct property notation)
    hidden [LapsPermissionLevel] $ScopeLevel
    hidden [LapsPermissionLevel] $RoleLevel
    hidden [string[]]            $GrantedScopes
    hidden [string[]]            $ActiveRoleIds
    hidden [string[]]            $PimEligibleRoleIds

    # ── Role template GUIDs — stable across all tenants, never change on rename
    # Source: https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference
    hidden static [string[]] $PasswordRoleIds = @(
        '62e90394-69f5-4237-9190-012177145e10'  # Global Administrator
        '7698a772-787b-4ac8-901f-60d6b08affd2'  # Cloud Device Administrator
        '3a2c62db-5318-420d-8d74-23affee5d9d5'  # Intune Administrator
    )
    hidden static [string[]] $MetadataRoleIds = @(
        '62e90394-69f5-4237-9190-012177145e10'  # Global Administrator
        '7698a772-787b-4ac8-901f-60d6b08affd2'  # Cloud Device Administrator
        '3a2c62db-5318-420d-8d74-23affee5d9d5'  # Intune Administrator
        '729827e3-9c14-49f7-bb1b-9608f156bbb8'  # Helpdesk Administrator
        '194ae4cb-b126-40b2-bd5b-6091b380977d'  # Security Administrator
        '5d6b6bb7-de71-4623-b4af-96380a352509'  # Security Reader
        'f2ef992c-3afb-46b9-b7cf-a126ee74c451'  # Global Reader
    )

    # ── Display names — used only in user-facing messages, not for gate checks
    hidden static [string[]] $PasswordRoleNames = @(
        'Global Administrator', 'Cloud Device Administrator', 'Intune Administrator'
    )
    hidden static [string[]] $MetadataRoleNames = @(
        'Global Administrator', 'Cloud Device Administrator', 'Intune Administrator',
        'Helpdesk Administrator', 'Security Administrator', 'Security Reader', 'Global Reader'
    )

    # ── Constructor — called by Build-LapsSession ────────────────────────────
    LapsSession([object]$GraphContext, [string[]]$Scopes, [object]$RoleInfo) {
        $this.Account        = $GraphContext.Account
        $this.TenantId       = $GraphContext.TenantId
        $this.GrantedScopes  = $Scopes
        $this.Connected      = $true

        # Guard against null role info (Get-UserRoleInfo is always best-effort)
        $this.ActiveRoles        = if ($RoleInfo.ActiveRoles)        { [string[]]$RoleInfo.ActiveRoles }        else { [string[]]@() }
        $this.ActiveRoleIds      = if ($RoleInfo.ActiveRoleIds)      { [string[]]$RoleInfo.ActiveRoleIds }      else { [string[]]@() }
        $this.PimEligibleRoles   = if ($RoleInfo.PimEligibleRoles)   { [string[]]$RoleInfo.PimEligibleRoles }   else { [string[]]@() }
        $this.PimEligibleRoleIds = if ($RoleInfo.PimEligibleRoleIds) { [string[]]$RoleInfo.PimEligibleRoleIds } else { [string[]]@() }
        $this.AuScopedRoles      = if ($RoleInfo.AuScopedRoles)      { [hashtable[]]$RoleInfo.AuScopedRoles }   else { [hashtable[]]@() }

        # Dual-gate: effective level is the lower of scope and role
        $this.ScopeLevel     = $this.EvaluateScopeGate()
        $this.RoleLevel      = $this.EvaluateRoleGate()
        $this.EffectiveLevel = [LapsPermissionLevel][Math]::Min(
            [int]$this.ScopeLevel,
            [int]$this.RoleLevel
        )
    }

    # ── Gate evaluators ──────────────────────────────────────────────────────

    hidden [LapsPermissionLevel] EvaluateScopeGate() {
        if ('DeviceLocalCredential.Read.All' -in $this.GrantedScopes) {
            return [LapsPermissionLevel]::Full
        }
        if ('DeviceLocalCredential.ReadBasic.All' -in $this.GrantedScopes) {
            return [LapsPermissionLevel]::Metadata
        }
        return [LapsPermissionLevel]::None
    }

    hidden [LapsPermissionLevel] EvaluateRoleGate() {
        # Compare against stable role template GUIDs — immune to display name renames.
        # Explicit foreach avoids PS 5.1 edge cases with Where-Object inside class methods.
        foreach ($Id in $this.ActiveRoleIds) {
            if ([LapsSession]::PasswordRoleIds -contains $Id) {
                return [LapsPermissionLevel]::Full
            }
        }
        foreach ($Id in $this.ActiveRoleIds) {
            if ([LapsSession]::MetadataRoleIds -contains $Id) {
                return [LapsPermissionLevel]::Metadata
            }
        }
        return [LapsPermissionLevel]::None
    }

    # ── Public helpers for cmdlets ───────────────────────────────────────────

    [void] AssertMinimumLevel([LapsPermissionLevel]$Required) {
        if ([int]$this.EffectiveLevel -lt [int]$Required) {
            [string]$Reason = $this.GetLimitingGateExplanation($Required)
            throw "Insufficient permissions (current: '$($this.EffectiveLevel)', required: '$Required'). $Reason"
        }
    }

    [bool] CanRetrievePasswords() {
        return $this.EffectiveLevel -eq [LapsPermissionLevel]::Full
    }

    [string] GetLimitingGateExplanation([LapsPermissionLevel]$Target) {
        $Parts = [System.Collections.Generic.List[string]]::new()
        if ([int]$this.ScopeLevel -lt [int]$Target) {
            $Parts.Add("API scope is '$($this.ScopeLevel)' — requires 'DeviceLocalCredential.Read.All' scope")
        }
        if ([int]$this.RoleLevel -lt [int]$Target) {
            [string]$RequiredRoles = if ($Target -eq [LapsPermissionLevel]::Full) {
                [LapsSession]::PasswordRoleNames -join ', '
            } else {
                [LapsSession]::MetadataRoleNames -join ', '
            }
            $Parts.Add("Entra role is '$($this.RoleLevel)' — requires one of: $RequiredRoles")
        }
        return $Parts -join '; and '
    }

    [string[]] GetPimUpgradeHints() {
        $Hints = [System.Collections.Generic.List[string]]::new()
        # Iterate by index so we can show the display name while comparing on GUID
        for ([int]$i = 0; $i -lt $this.PimEligibleRoleIds.Count; $i++) {
            [string]$Id          = $this.PimEligibleRoleIds[$i]
            [string]$DisplayName = if ($i -lt $this.PimEligibleRoles.Count) { $this.PimEligibleRoles[$i] } else { $Id }
            [LapsPermissionLevel]$WouldBe = if ([LapsSession]::PasswordRoleIds -contains $Id) {
                [LapsPermissionLevel]::Full
            } elseif ([LapsSession]::MetadataRoleIds -contains $Id) {
                [LapsPermissionLevel]::Metadata
            } else {
                continue
            }
            if ([int]$WouldBe -gt [int]$this.EffectiveLevel) {
                $Hints.Add("Activate PIM role '$DisplayName' to reach permission level '$WouldBe'. Go to: https://entra.microsoft.com")
            }
        }
        return $Hints.ToArray()
    }

    [bool] HasAuScopedRoles() {
        return ($this.AuScopedRoles.Count -gt 0)
    }
}

# ─── Module-scoped session singleton ─────────────────────────────────────────
# Populated by Build-LapsSession (called from Connect-IntuneLaps and Show-IntuneLapsGui).
# Cleared by Disconnect-IntuneLaps. Read via Get-CurrentSession.
$script:CurrentSession = $null

$ErrorActionPreference = 'Stop'

# ─── Bootstrap: ensure Microsoft.Graph.Authentication is available ────────────
[string]$GraphAuthModule = 'Microsoft.Graph.Authentication'
[version]$GraphAuthMinVersion = '2.0.0'

$AvailableVersion = Get-Module -ListAvailable -Name $GraphAuthModule |
    Where-Object { $_.Version -ge $GraphAuthMinVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $AvailableVersion) {
    Write-Warning "Installing required module: $GraphAuthModule (minimum v$GraphAuthMinVersion)..."
    try {
        Install-Module -Name $GraphAuthModule -Scope CurrentUser -Force -AllowClobber -MinimumVersion $GraphAuthMinVersion.ToString() -ErrorAction Stop
    }
    catch {
        throw "Could not install '$GraphAuthModule' v$($GraphAuthMinVersion)+. Please run: Install-Module $GraphAuthModule -MinimumVersion $GraphAuthMinVersion -Scope CurrentUser"
    }
}

if (-not (Get-Module -Name $GraphAuthModule)) {
    Import-Module -Name $GraphAuthModule -MinimumVersion $GraphAuthMinVersion.ToString() -ErrorAction Stop
}

# Discover and dot-source Private functions
$PrivatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
if (Test-Path -Path $PrivatePath) {
    $PrivateFiles = Get-ChildItem -Path $PrivatePath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($File in $PrivateFiles) {
        try {
            . $File.FullName
        }
        catch {
            Write-Error -Message "Failed to import private function [$($File.BaseName)]: $_"
        }
    }
}

# Discover and dot-source Public functions
$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
if (Test-Path -Path $PublicPath) {
    $PublicFiles = Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    foreach ($File in $PublicFiles) {
        try {
            . $File.FullName
        }
        catch {
            Write-Error -Message "Failed to import public function [$($File.BaseName)]: $_"
        }
    }

    # Exports are controlled by FunctionsToExport in IntuneLaps.psd1
}
