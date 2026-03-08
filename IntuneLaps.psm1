#Requires -Version 5.1

<#
.SYNOPSIS
    IntuneLaps root module loader.
.DESCRIPTION
    Dot-sources all Public and Private function files and exports Public functions.
    Automatically installs Microsoft.Graph.Authentication if not present.
#>

$ErrorActionPreference = 'Stop'

# ─── Bootstrap: ensure Microsoft.Graph.Authentication is available ────────────
[string]$GraphAuthModule = 'Microsoft.Graph.Authentication'
if (-not (Get-Module -ListAvailable -Name $GraphAuthModule)) {
    Write-Host "Installing required module: $GraphAuthModule ..." -ForegroundColor Cyan
    try {
        Install-Module -Name $GraphAuthModule -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    catch {
        throw "Could not install '$GraphAuthModule'. Please run: Install-Module $GraphAuthModule -Scope CurrentUser"
    }
}

if (-not (Get-Module -Name $GraphAuthModule)) {
    Import-Module -Name $GraphAuthModule -ErrorAction Stop
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

    # Export all public functions
    $PublicFiles | ForEach-Object {
        Export-ModuleMember -Function $_.BaseName
    }
}
