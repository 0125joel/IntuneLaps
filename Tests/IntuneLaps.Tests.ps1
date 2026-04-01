#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the IntuneLaps PowerShell module.
#>

$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\IntuneLaps.psd1'
Import-Module -Name $ModulePath -Force -ErrorAction Stop

# ─── Helper: build a [LapsSession] inside module scope ───────────────────────
# Reused across multiple Describe blocks via BeforeEach closures.
function New-TestSession {
    param(
        [string[]]$Scopes      = @('DeviceLocalCredential.Read.All', 'DeviceManagementManagedDevices.Read.All'),
        [string[]]$ActiveRoles = @('Cloud Device Administrator'),
        [string[]]$PimRoles    = @(),
        [hashtable[]]$AuRoles  = @()
    )
    InModuleScope IntuneLaps -ArgumentList $Scopes, $ActiveRoles, $PimRoles, $AuRoles {
        param($Scopes, $ActiveRoles, $PimRoles, $AuRoles)
        $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123'; Scopes = $Scopes }
        $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]$ActiveRoles; ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]$PimRoles; PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]$AuRoles }
        $script:CurrentSession = [LapsSession]::new($ctx, $Scopes, $ri)
    }
}

# ─── LapsSession — EvaluateScopeGate ─────────────────────────────────────────
Describe 'LapsSession — EvaluateScopeGate' {
    It 'Returns Full when DeviceLocalCredential.Read.All scope is present' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.ScopeLevel | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Returns Metadata when only ReadBasic.All scope is present' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.ReadBasic.All'), $ri)
            $s.ScopeLevel | Should -Be ([LapsPermissionLevel]::Metadata)
        }
    }

    It 'Returns None when no LAPS scopes are present' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('User.Read'), $ri)
            $s.ScopeLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }
}

# ─── LapsSession — EvaluateRoleGate ──────────────────────────────────────────
Describe 'LapsSession — EvaluateRoleGate' {
    It 'Returns Full for Cloud Device Administrator' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Returns Full for Intune Administrator' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Intune Administrator'); ActiveRoleIds = [string[]]@('3a2c62db-5318-420d-8d74-23affee5d9d5'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Returns Metadata for Helpdesk Administrator' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Helpdesk Administrator'); ActiveRoleIds = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::Metadata)
        }
    }

    It 'Returns Metadata for Security Reader' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Security Reader'); ActiveRoleIds = [string[]]@('5d6b6bb7-de71-4623-b4af-96380a352509'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::Metadata)
        }
    }

    It 'Returns None when no qualifying role is assigned' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('User Administrator'); ActiveRoleIds = [string[]]@('fe930be7-5e62-47db-91af-98c3a49a38b1'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }

    It 'Returns None when ActiveRoles is empty' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.RoleLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }
}

# ─── LapsSession — Dual-gate EffectiveLevel ───────────────────────────────────
Describe 'LapsSession — Dual-gate EffectiveLevel' {
    It 'Read.All scope + Cloud Device Admin role → Full' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Read.All scope + Helpdesk Admin role → Metadata (role is limiting gate)' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Helpdesk Administrator'); ActiveRoleIds = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::Metadata)
            $s.ScopeLevel     | Should -Be ([LapsPermissionLevel]::Full)
            $s.RoleLevel      | Should -Be ([LapsPermissionLevel]::Metadata)
        }
    }

    It 'ReadBasic.All scope + Cloud Device Admin role → Metadata (scope is limiting gate)' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.ReadBasic.All'), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::Metadata)
            $s.ScopeLevel     | Should -Be ([LapsPermissionLevel]::Metadata)
            $s.RoleLevel      | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Read.All scope + no qualifying role → None (role gate blocks)' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }

    It 'No LAPS scope + Cloud Device Admin role → None (scope gate blocks)' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('User.Read'), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }

    It 'No LAPS scope + no qualifying role → None' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @(), $ri)
            $s.EffectiveLevel | Should -Be ([LapsPermissionLevel]::None)
        }
    }
}

# ─── LapsSession — AssertMinimumLevel ────────────────────────────────────────
Describe 'LapsSession — AssertMinimumLevel' {
    It 'Does not throw when EffectiveLevel meets requirement' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            { $s.AssertMinimumLevel([LapsPermissionLevel]::Full) } | Should -Not -Throw
        }
    }

    It 'Throws when EffectiveLevel is below requirement' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Helpdesk Administrator'); ActiveRoleIds = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            { $s.AssertMinimumLevel([LapsPermissionLevel]::Full) } | Should -Throw '*Insufficient permissions*'
        }
    }

    It 'Throw message identifies the limiting gate' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Helpdesk Administrator'); ActiveRoleIds = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            [string]$Message = ''
            try { $s.AssertMinimumLevel([LapsPermissionLevel]::Full) } catch { $Message = $_.Exception.Message }
            $Message | Should -Match 'Entra role'
        }
    }
}

# ─── LapsSession — GetLimitingGateExplanation ─────────────────────────────────
Describe 'LapsSession — GetLimitingGateExplanation' {
    It 'Mentions scope when scope is the limiting gate' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.ReadBasic.All'), $ri)
            $s.GetLimitingGateExplanation([LapsPermissionLevel]::Full) | Should -Match 'API scope'
        }
    }

    It 'Mentions Entra role when role is the limiting gate' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Helpdesk Administrator'); ActiveRoleIds = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.GetLimitingGateExplanation([LapsPermissionLevel]::Full) | Should -Match 'Entra role'
        }
    }

    It 'Mentions both gates when both are limiting' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('User.Read'), $ri)
            $Explanation = $s.GetLimitingGateExplanation([LapsPermissionLevel]::Full)
            $Explanation | Should -Match 'API scope'
            $Explanation | Should -Match 'Entra role'
        }
    }
}

# ─── LapsSession — GetPimUpgradeHints ────────────────────────────────────────
Describe 'LapsSession — GetPimUpgradeHints' {
    It 'Returns a hint when a PIM-eligible role would raise the level' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{
                ActiveRoles        = [string[]]@('Helpdesk Administrator')
                ActiveRoleIds      = [string[]]@('729827e3-9c14-49f7-bb1b-9608f156bbb8')
                PimEligibleRoles   = [string[]]@('Cloud Device Administrator')
                PimEligibleRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2')
                AuScopedRoles      = [hashtable[]]@()
            }
            $s     = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $Hints = $s.GetPimUpgradeHints()
            $Hints.Count | Should -BeGreaterThan 0
            $Hints[0]    | Should -Match 'Cloud Device Administrator'
        }
    }

    It 'Returns no hints when already at Full level' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{
                ActiveRoles        = [string[]]@('Cloud Device Administrator')
                ActiveRoleIds      = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2')
                PimEligibleRoles   = [string[]]@('Intune Administrator')
                PimEligibleRoleIds = [string[]]@('3a2c62db-5318-420d-8d74-23affee5d9d5')
                AuScopedRoles      = [hashtable[]]@()
            }
            $s     = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $Hints = $s.GetPimUpgradeHints()
            $Hints.Count | Should -Be 0
        }
    }

    It 'Returns no hints when PimEligibleRoles is empty' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.GetPimUpgradeHints().Count | Should -Be 0
        }
    }
}

# ─── LapsSession — HasAuScopedRoles ──────────────────────────────────────────
Describe 'LapsSession — HasAuScopedRoles' {
    It 'Returns true when AuScopedRoles contains entries' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{
                ActiveRoles        = [string[]]@('Cloud Device Administrator')
                ActiveRoleIds      = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2')
                PimEligibleRoles   = [string[]]@()
                PimEligibleRoleIds = [string[]]@()
                AuScopedRoles      = [hashtable[]]@(@{ RoleName = 'Cloud Device Administrator'; AuId = '/administrativeUnits/guid'; AuDisplayName = 'Corp AU' })
            }
            $s = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.HasAuScopedRoles() | Should -BeTrue
        }
    }

    It 'Returns false when AuScopedRoles is empty' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $s   = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            $s.HasAuScopedRoles() | Should -BeFalse
        }
    }
}

# ─── Get-CurrentSession ───────────────────────────────────────────────────────
Describe 'Get-CurrentSession' {
    It 'Throws with a clear message when session is null' {
        InModuleScope IntuneLaps {
            $script:CurrentSession = $null
            { Get-CurrentSession } | Should -Throw '*Not connected*'
        }
    }

    It 'Throws when session is present but Connected is false' {
        InModuleScope IntuneLaps {
            $script:CurrentSession = [PSCustomObject]@{ Connected = $false }
            { Get-CurrentSession } | Should -Throw '*Not connected*'
        }
    }

    It 'Returns the session when Connected is true' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'x@t.com'; TenantId = 'tid' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
            Get-CurrentSession | Should -Not -BeNull
        }
    }
}

# ─── Build-LapsSession ────────────────────────────────────────────────────────
Describe 'Build-LapsSession' {
    It 'Stores a [LapsSession] in $script:CurrentSession' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tid'; Scopes = @('DeviceLocalCredential.Read.All') }
        }
        Mock -ModuleName IntuneLaps Get-UserRoleInfo {
            [PSCustomObject]@{
                ActiveRoles        = [string[]]@('Cloud Device Administrator')
                ActiveRoleIds      = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2')
                PimEligibleRoles   = [string[]]@()
                PimEligibleRoleIds = [string[]]@()
                AuScopedRoles      = [hashtable[]]@()
            }
        }
        InModuleScope IntuneLaps {
            $script:CurrentSession = $null
            Build-LapsSession
            $script:CurrentSession         | Should -Not -BeNull
            $script:CurrentSession.Account | Should -Be 'test@contoso.com'
            $script:CurrentSession.EffectiveLevel | Should -Be ([LapsPermissionLevel]::Full)
        }
    }

    It 'Throws when Get-MgContext returns null' {
        Mock -ModuleName IntuneLaps Get-MgContext { $null }
        InModuleScope IntuneLaps {
            { Build-LapsSession } | Should -Throw
        }
    }

    It 'Returns the constructed session' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tid'; Scopes = @('DeviceLocalCredential.ReadBasic.All') }
        }
        Mock -ModuleName IntuneLaps Get-UserRoleInfo {
            [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
        }
        InModuleScope IntuneLaps {
            $Result = Build-LapsSession
            $Result | Should -Not -BeNull
            $Result.Connected | Should -BeTrue
        }
    }
}

# ─── ConvertFrom-LapsPassword ─────────────────────────────────────────────────
Describe 'ConvertFrom-LapsPassword' {
    It 'Decodes a known UTF-16LE Base64 LAPS password correctly' {
        [string]$Decoded = InModuleScope IntuneLaps {
            [string]$Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('P@ssw0rd!'))
            ConvertFrom-LapsPassword -PasswordBase64 $Encoded
        }
        $Decoded | Should -Be 'P@ssw0rd!'
    }

    It 'Returns null and writes an error for invalid Base64' {
        InModuleScope IntuneLaps {
            { ConvertFrom-LapsPassword -PasswordBase64 '!!NotBase64!!' } | Should -Throw
        }
    }
}

# ─── Get-UserRoleInfo ─────────────────────────────────────────────────────────
Describe 'Get-UserRoleInfo' {
    It 'Returns correct ActiveRoles and PimEligibleRoles from mocked Graph responses' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') {
                @{ id = 'user-guid-123' }
            }
            elseif ($Uri -match 'roleAssignments') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Cloud Device Administrator' }; roleDefinitionId = '7698a772-787b-4ac8-901f-60d6b08affd2'; directoryScopeId = '/' }) }
            }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Intune Administrator'; id = '3a2c62db-5318-420d-8d74-23affee5d9d5' } }) }
            }
            else { @{} }
        }
        $Result = InModuleScope IntuneLaps { Get-UserRoleInfo }
        $Result.ActiveRoles        | Should -Be @('Cloud Device Administrator')
        $Result.ActiveRoleIds      | Should -Be @('7698a772-787b-4ac8-901f-60d6b08affd2')
        $Result.PimEligibleRoles   | Should -Be @('Intune Administrator')
        $Result.PimEligibleRoleIds | Should -Be @('3a2c62db-5318-420d-8d74-23affee5d9d5')
        $Result.HasPimEligible     | Should -BeTrue
    }

    It 'Returns empty-safe object when any Graph call throws' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest { throw 'Simulated failure' }
        $Result = InModuleScope IntuneLaps { Get-UserRoleInfo }
        $Result.ActiveRoles.Count      | Should -Be 0
        $Result.PimEligibleRoles.Count | Should -Be 0
        $Result.HasPimEligible         | Should -BeFalse
    }

    It 'Does not throw when user ID lookup returns null' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') { @{ id = $null } }
            else { @{} }
        }
        { InModuleScope IntuneLaps { Get-UserRoleInfo } } | Should -Not -Throw
    }

    It 'Returns AuScopedRoles as hashtable[] with RoleName, AuId, AuDisplayName' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') {
                @{ id = 'user-guid-123' }
            }
            elseif ($Uri -match 'roleAssignments') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Cloud Device Administrator' }; roleDefinitionId = '7698a772-787b-4ac8-901f-60d6b08affd2'; directoryScopeId = '/administrativeUnits/au-guid-456' }) }
            }
            elseif ($Uri -match 'administrativeUnits') {
                @{ displayName = 'Corp Devices AU' }
            }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') { @{ value = @() } }
            else { @{} }
        }
        $Result = InModuleScope IntuneLaps { Get-UserRoleInfo }
        $Result.AuScopedRoles.Count                 | Should -Be 1
        $Result.AuScopedRoles[0]['RoleName']        | Should -Be 'Cloud Device Administrator'
        $Result.AuScopedRoles[0]['AuId']            | Should -BeLike '*/administrativeUnits/*'
        $Result.AuScopedRoles[0]['AuDisplayName']   | Should -Be 'Corp Devices AU'
        $Result.HasAuScopedRoles                    | Should -BeTrue
    }

    It 'Tenant-wide role assignments leave AuScopedRoles empty' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') {
                @{ id = 'user-guid-123' }
            }
            elseif ($Uri -match 'roleAssignments') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Cloud Device Administrator' }; roleDefinitionId = '7698a772-787b-4ac8-901f-60d6b08affd2'; directoryScopeId = '/' }) }
            }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') { @{ value = @() } }
            else { @{} }
        }
        $Result = InModuleScope IntuneLaps { Get-UserRoleInfo }
        $Result.AuScopedRoles.Count | Should -Be 0
        $Result.HasAuScopedRoles    | Should -BeFalse
    }

    It 'Empty result includes AuScopedRoles and HasAuScopedRoles properties' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest { throw 'Simulated failure' }
        $Result = InModuleScope IntuneLaps { Get-UserRoleInfo }
        $Result.PSObject.Properties.Name -contains 'AuScopedRoles'    | Should -BeTrue
        $Result.PSObject.Properties.Name -contains 'HasAuScopedRoles' | Should -BeTrue
        $Result.AuScopedRoles.Count | Should -Be 0
        $Result.HasAuScopedRoles    | Should -BeFalse
    }
}

# ─── Disconnect-IntuneLaps ────────────────────────────────────────────────────
Describe 'Disconnect-IntuneLaps' {
    It 'Clears $script:CurrentSession' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All'), $ri)
        }
        Mock -ModuleName IntuneLaps Disconnect-MgGraph {}
        Disconnect-IntuneLaps
        InModuleScope IntuneLaps { $script:CurrentSession } | Should -BeNullOrEmpty
    }

    It 'Does not throw when already disconnected' {
        InModuleScope IntuneLaps { $script:CurrentSession = $null }
        Mock -ModuleName IntuneLaps Disconnect-MgGraph {}
        { Disconnect-IntuneLaps } | Should -Not -Throw
    }
}

# ─── Connect-IntuneLaps ───────────────────────────────────────────────────────
Describe 'Connect-IntuneLaps' {
    BeforeEach {
        Mock -ModuleName IntuneLaps Connect-MgGraph {}
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{
                Account  = 'test@contoso.com'
                TenantId = 'tenant-guid-123'
                Scopes   = @('DeviceLocalCredential.Read.All', 'DeviceLocalCredential.ReadBasic.All', 'RoleManagement.Read.Directory')
            }
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') { @{ id = 'user-guid-123' } }
            elseif ($Uri -match 'roleAssignments') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Cloud Device Administrator' }; roleDefinitionId = '7698a772-787b-4ac8-901f-60d6b08affd2'; directoryScopeId = '/' }) }
            }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') { @{ value = @() } }
            else { @{} }
        }
    }

    It 'Returns a [LapsSession] object' {
        $Result = Connect-IntuneLaps
        $Result              | Should -Not -BeNull
        $Result.Connected    | Should -BeTrue
        $Result.Account      | Should -Be 'test@contoso.com'
    }

    It 'EffectiveLevel is Full when scope and role both qualify' {
        $Result = Connect-IntuneLaps
        $Result.EffectiveLevel.ToString() | Should -Be 'Full'
    }

    It 'ActiveRoles contains role names from Graph' {
        $Result = Connect-IntuneLaps
        $Result.ActiveRoles -contains 'Cloud Device Administrator' | Should -BeTrue
    }

    It 'Stores session in $script:CurrentSession' {
        Connect-IntuneLaps
        InModuleScope IntuneLaps {
            $script:CurrentSession | Should -Not -BeNull
        }
    }

    It 'Writes a warning when EffectiveLevel is None' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tid'; Scopes = @('User.Read') }
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') { @{ id = 'user-guid-123' } }
            elseif ($Uri -match 'roleAssignments') { @{ value = @() } }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') { @{ value = @() } }
            else { @{} }
        }
        Connect-IntuneLaps -WarningVariable Warn 3>$null
        $Warn | Should -Not -BeNullOrEmpty
    }

    It 'Writes a PIM upgrade hint when eligible role would raise EffectiveLevel' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tid'; Scopes = @('DeviceLocalCredential.Read.All') }
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '/me\?') { @{ id = 'user-guid-123' } }
            elseif ($Uri -match 'roleAssignments') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Helpdesk Administrator' }; roleDefinitionId = '729827e3-9c14-49f7-bb1b-9608f156bbb8'; directoryScopeId = '/' }) }
            }
            elseif ($Uri -match 'roleEligibilityScheduleInstances') {
                @{ value = @(@{ roleDefinition = @{ displayName = 'Cloud Device Administrator' }; roleDefinitionId = '7698a772-787b-4ac8-901f-60d6b08affd2' }) }
            }
            else { @{} }
        }
        Connect-IntuneLaps -WarningVariable Warn 3>$null
        $Warn | Should -Not -BeNullOrEmpty
        ($Warn | Where-Object { $_ -match 'PIM' -or $_ -match 'Cloud Device' }).Count | Should -BeGreaterThan 0
    }
}

# ─── Find-IntuneLapsDevice ────────────────────────────────────────────────────
Describe 'Find-IntuneLapsDevice' {
    BeforeEach {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All', 'DeviceLocalCredential.ReadBasic.All'), $ri)
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            @{
                value = @(
                    @{ id = 'aaaa-1111'; azureADDeviceId = 'dev-guid-1'; deviceName = 'DESKTOP-001'; operatingSystem = 'Windows'; osVersion = '10.0.22621'; managementState = 'managed'; lastSyncDateTime = '2024-01-01T00:00:00Z' }
                    @{ id = 'bbbb-2222'; azureADDeviceId = 'dev-guid-2'; deviceName = 'DESKTOP-002'; operatingSystem = 'Windows'; osVersion = '10.0.22621'; managementState = 'managed'; lastSyncDateTime = '2024-01-02T00:00:00Z' }
                )
            }
        }
    }

    It 'Returns a list of devices matching the search' {
        [array]$Result = Find-IntuneLapsDevice -DeviceName 'DESKTOP'
        $Result.Count | Should -Be 2
    }

    It 'Returns PSCustomObjects with the correct properties' {
        [array]$Result = Find-IntuneLapsDevice -DeviceName 'DESKTOP'
        $Result[0].PSObject.Properties.Name -contains 'DeviceId'         | Should -BeTrue
        $Result[0].PSObject.Properties.Name -contains 'DeviceName'       | Should -BeTrue
        $Result[0].PSObject.Properties.Name -contains 'LastSyncDateTime' | Should -BeTrue
    }

    It 'Warns when no devices are found' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest { @{ value = @() } }
        Find-IntuneLapsDevice -DeviceName 'NOTEXISTING' -WarningVariable Warn 3>$null
        $Warn | Should -Not -BeNullOrEmpty
    }

    It 'Throws when not connected' {
        InModuleScope IntuneLaps { $script:CurrentSession = $null }
        { Find-IntuneLapsDevice -DeviceName 'DESKTOP' } | Should -Throw '*Not connected*'
    }

    It 'Throws when EffectiveLevel is None' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@(); ActiveRoleIds = [string[]]@(); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('User.Read'), $ri)
        }
        { Find-IntuneLapsDevice -DeviceName 'DESKTOP' } | Should -Throw '*Insufficient permissions*'
    }
}

# ─── Get-IntuneLapsCredential ─────────────────────────────────────────────────
Describe 'Get-IntuneLapsCredential' {
    BeforeEach {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('DeviceLocalCredential.Read.All', 'DeviceLocalCredential.ReadBasic.All'), $ri)
        }
    }

    It 'Does not have an IncludePassword parameter' {
        $Cmd = Get-Command -Module IntuneLaps -Name Get-IntuneLapsCredential
        $Cmd.Parameters.ContainsKey('IncludePassword') | Should -BeFalse
    }

    It 'Returns metadata properties on the result object' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            param($Parameters)
            @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111'
        $Result.DeviceName         | Should -Be 'DESKTOP-001'
        $Result.LastBackupDateTime | Should -Be '2024-01-01'
    }

    It 'Returns EffectiveLevel on the result object' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111'
        $Result.EffectiveLevel.ToString() | Should -Be 'Full'
    }

    It 'Returns all credentials sorted newest-first when EffectiveLevel is Full' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            param($Parameters)
            if ($Parameters.Uri -match '\$select=') {
                @{
                    credentials = @(
                        @{ accountName = 'OldAdmin';  accountSid = 'S-1-0'; backupDateTime = '2024-01-01T00:00:00Z'; passwordBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('OldPass')) }
                        @{ accountName = 'LAPSAdmin'; accountSid = 'S-1-1'; backupDateTime = '2024-06-01T00:00:00Z'; passwordBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('NewPass')) }
                    )
                }
            } else {
                @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-06-01'; refreshDateTime = '2024-07-01' }
            }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111'
        $Result.Credentials.Count       | Should -Be 2
        $Result.Credentials[0].AccountName | Should -Be 'LAPSAdmin'   # Newest first
        $Result.Credentials[1].AccountName | Should -Be 'OldAdmin'
        $Result.Credentials[0].Password    | Should -Be 'NewPass'
    }

    It 'Returns null Credentials when EffectiveLevel is Metadata' {
        InModuleScope IntuneLaps {
            $ctx = [PSCustomObject]@{ Account = 'test@contoso.com'; TenantId = 'tenant-guid-123' }
            $ri  = [PSCustomObject]@{ ActiveRoles = [string[]]@('Cloud Device Administrator'); ActiveRoleIds = [string[]]@('7698a772-787b-4ac8-901f-60d6b08affd2'); PimEligibleRoles = [string[]]@(); PimEligibleRoleIds = [string[]]@(); AuScopedRoles = [hashtable[]]@() }
            $script:CurrentSession = [LapsSession]::new($ctx, @('DeviceLocalCredential.ReadBasic.All'), $ri)
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue
        $Result.Credentials    | Should -BeNullOrEmpty
        $Result.EffectiveLevel.ToString() | Should -Be 'Metadata'
    }

    It 'Writes a warning (not throws) on HTTP 403 when retrieving credentials' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            param($Parameters)
            if ($Parameters.Uri -match '\$select=') { throw '403 Forbidden' }
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        { Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Writes a warning and does not throw on 404 (no LAPS record)' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry { throw '404 Not Found' }
        { Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Throws when not connected' {
        InModuleScope IntuneLaps { $script:CurrentSession = $null }
        { Get-IntuneLapsCredential -DeviceId 'aaaa-1111' } | Should -Throw '*Not connected*'
    }

    It 'Accepts pipeline input from Find-IntuneLapsDevice via DeviceId property' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $PipeInput = [PSCustomObject]@{ DeviceId = 'aaaa-1111'; DeviceName = 'DESKTOP-001' }
        $Result = $PipeInput | Get-IntuneLapsCredential -WarningAction SilentlyContinue
        $Result.DeviceId | Should -Be 'aaaa-1111'
    }

    It 'Accepts -DeviceName and resolves via Find-IntuneLapsDevice internally' {
        Mock -ModuleName IntuneLaps Find-IntuneLapsDevice {
            [PSCustomObject]@{ DeviceId = 'aaaa-1111'; DeviceName = 'DESKTOP-001' }
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceName 'DESKTOP-001' -ExactMatch -WarningAction SilentlyContinue
        $Result | Should -Not -BeNull
        $Result.DeviceName | Should -Be 'DESKTOP-001'
        Assert-MockCalled -ModuleName IntuneLaps Find-IntuneLapsDevice -ParameterFilter { $DeviceName -eq 'DESKTOP-001' -and $ExactMatch -eq $true } -Times 1
    }

    It '-DeviceName returns credentials for multiple matching devices' {
        Mock -ModuleName IntuneLaps Find-IntuneLapsDevice {
            [PSCustomObject]@{ DeviceId = 'dev-1'; DeviceName = 'DESKTOP-001' }
            [PSCustomObject]@{ DeviceId = 'dev-2'; DeviceName = 'DESKTOP-002' }
        }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            param($Parameters)
            if ($Parameters.Uri -match 'dev-1') { @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' } }
            else                                { @{ deviceName = 'DESKTOP-002'; lastBackupDateTime = '2024-01-02'; refreshDateTime = '2024-06-01' } }
        }
        [array]$Results = Get-IntuneLapsCredential -DeviceName 'DESKTOP-' -WarningAction SilentlyContinue
        $Results.Count | Should -Be 2
    }

    It 'IsPasswordExpired is $true when refreshDateTime is in the past' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue
        $Result.IsPasswordExpired | Should -BeTrue
    }

    It 'IsPasswordExpired is $false when refreshDateTime is in the future' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2025-01-01'; refreshDateTime = '2099-01-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue
        $Result.IsPasswordExpired | Should -BeFalse
    }

    It 'IsPasswordExpired is $null when refreshDateTime is absent' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequestWithRetry {
            @{ deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -WarningAction SilentlyContinue
        $Result.IsPasswordExpired | Should -BeNullOrEmpty
    }

    It 'Has a DeviceName parameter set with ExactMatch switch' {
        $Cmd = Get-Command -Module IntuneLaps -Name Get-IntuneLapsCredential
        $Cmd.Parameters.ContainsKey('DeviceName')  | Should -BeTrue
        $Cmd.Parameters.ContainsKey('ExactMatch')  | Should -BeTrue
    }
}
