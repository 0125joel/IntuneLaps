#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the IntuneLaps PowerShell module.
#>

$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\IntuneLaps.psd1'
Import-Module -Name $ModulePath -Force -ErrorAction Stop

# ─── ConvertFrom-LapsPassword ─────────────────────────────────────────────────
Describe 'ConvertFrom-LapsPassword' {
    It 'Decodes a known Base64 LAPS password correctly' {
        [string]$Decoded  = InModuleScope IntuneLaps {
            [string]$Encoded  = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('P@ssw0rd!'))
            ConvertFrom-LapsPassword -PasswordBase64 $Encoded
        }
        $Decoded | Should Be 'P@ssw0rd!'
    }

    It 'Returns null and writes an error for invalid Base64' {
        InModuleScope IntuneLaps {
            { ConvertFrom-LapsPassword -PasswordBase64 '!!NotBase64!!' } | Should Throw
        }
    }
}

# ─── Test-LapsPermission ──────────────────────────────────────────────────────
Describe 'Test-LapsPermission' {
    It 'Returns Full when DeviceLocalCredential.Read.All scope is present' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Scopes = @('DeviceLocalCredential.Read.All', 'DeviceLocalCredential.ReadBasic.All') }
        }
        InModuleScope IntuneLaps { Test-LapsPermission } | Should Be 'Full'
    }

    It 'Returns Metadata when only ReadBasic.All scope is present' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Scopes = @('DeviceLocalCredential.ReadBasic.All') }
        }
        InModuleScope IntuneLaps { Test-LapsPermission } | Should Be 'Metadata'
    }

    It 'Returns None when no LAPS scopes are present' {
        Mock -ModuleName IntuneLaps Get-MgContext {
            [PSCustomObject]@{ Scopes = @('User.Read') }
        }
        InModuleScope IntuneLaps { Test-LapsPermission } | Should Be 'None'
    }

    It 'Returns None when not connected' {
        Mock -ModuleName IntuneLaps Get-MgContext { throw 'Not connected' }
        InModuleScope IntuneLaps { Test-LapsPermission } | Should Be 'None'
    }
}

# ─── Find-IntuneLapsDevice ────────────────────────────────────────────────────
Describe 'Find-IntuneLapsDevice' {
    BeforeEach {
        Mock -ModuleName IntuneLaps Get-MgContext { [PSCustomObject]@{ Account = 'test@contoso.com' } }
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            @{
                value = @(
                    @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; operatingSystem = 'Windows'; osVersion = '10.0.22621'; managementState = 'managed'; joinType = 'azureADJoined'; lastSyncDateTime = '2024-01-01T00:00:00Z' }
                    @{ id = 'bbbb-2222'; deviceName = 'DESKTOP-002'; operatingSystem = 'Windows'; osVersion = '10.0.22621'; managementState = 'managed'; joinType = 'azureADJoined'; lastSyncDateTime = '2024-01-02T00:00:00Z' }
                )
            }
        }
    }

    It 'Returns a list of devices matching the search' {
        [array]$Result = Find-IntuneLapsDevice -DeviceName 'DESKTOP'
        $Result.Count | Should Be 2
    }

    It 'Returns PSCustomObjects with the correct properties' {
        [array]$Result = Find-IntuneLapsDevice -DeviceName 'DESKTOP'
        $Result[0].PSObject.Properties.Name -contains 'DeviceId' | Should Be $true
        $Result[0].PSObject.Properties.Name -contains 'DeviceName' | Should Be $true
        $Result[0].PSObject.Properties.Name -contains 'LastSyncDateTime' | Should Be $true
    }

    It 'Warns when no devices are found' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest { @{ value = @() } }
        $Result = Find-IntuneLapsDevice -DeviceName 'NOTEXISTING' -WarningVariable Warn 3>$null
        $Warn | Should Not BeNullOrEmpty
    }

    It 'Throws when not connected to Graph' {
        Mock -ModuleName IntuneLaps Get-MgContext { throw 'Not connected' }
        { Find-IntuneLapsDevice -DeviceName 'DESKTOP' } | Should Throw
    }
}

# ─── Get-IntuneLapsCredential ─────────────────────────────────────────────────
Describe 'Get-IntuneLapsCredential' {
    BeforeEach {
        Mock -ModuleName IntuneLaps Get-MgContext { [PSCustomObject]@{ Account = 'test@contoso.com' } }
    }

    It 'Returns credential object without password when -IncludePassword is not specified' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }
        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111'
        $Result.DeviceName        | Should Be 'DESKTOP-001'
        $Result.PasswordRetrieved | Should Be $false
        $Result.Password          | Should BeNullOrEmpty
    }

    It 'Returns decoded password when -IncludePassword is specified and user has permissions' {
        $Script:EncodedPw = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes('S3cur3!Pass'))

        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '\$select=credentials') {
                @{
                    id = 'aaaa-1111'; deviceName = 'DESKTOP-001'
                    lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01'
                    credentials = @(@{ accountName = 'LocalAdmin'; accountSid = 'S-1-5'; backupDateTime = '2024-01-01'; passwordBase64 = 'UzAzAGMAdQByADMAMQBQAGEAcwBzAA==' })
                }
            } else {
                @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
            }
        }

        $Result = Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -IncludePassword
        $Result.Password          | Should Be 'S3cur3!Pass'
        $Result.AccountName       | Should Be 'LocalAdmin'
        $Result.PasswordRetrieved | Should Be $true
    }

    It 'Writes a warning (not throws) on HTTP 403 for password' {
        Mock -ModuleName IntuneLaps Invoke-MgGraphRequest {
            param($Method, $Uri)
            if ($Uri -match '\$select=credentials') { throw '403 Forbidden' }
            @{ id = 'aaaa-1111'; deviceName = 'DESKTOP-001'; lastBackupDateTime = '2024-01-01'; refreshDateTime = '2024-06-01' }
        }

        { Get-IntuneLapsCredential -DeviceId 'aaaa-1111' -IncludePassword -WarningAction SilentlyContinue } | Should Not Throw
    }
}
