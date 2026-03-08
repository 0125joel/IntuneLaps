# IntuneLaps

A PowerShell module with WPF GUI for securely retrieving **Intune LAPS** (Local Administrator Password Solution) credentials via the Microsoft Graph API.

## Features

- 🔍 **Device Search** — find Intune-managed devices by name (prefix search)
- 👤 **Username retrieval** — works with basic LAPS permissions
- 🔑 **Password retrieval** — requires elevated Entra role (Cloud Device Administrator / Intune Administrator)
- 👁 **Toggle visibility** — reveal or mask the password on demand
- 📋 **Copy buttons** — copy username or password to clipboard
- 🗑 **Auto-clear clipboard** — password is automatically cleared from clipboard after 30 seconds
- 🌗 **Windows theme-aware** — GUI respects your dark/light mode setting
- ⌨️ **Dual-mode** — fully usable via CLI *and* WPF GUI

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- `Microsoft.Graph.Authentication` module ≥ 2.0.0
- An Entra ID account with one of:
  - **Helpdesk Administrator** (or higher) — for username/metadata
  - **Cloud Device Administrator** or **Intune Administrator** — for password

## Installation

```powershell
# 1. Clone or download this repository
# 2. Install the Graph dependency
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser

# 3. Import the module
Import-Module .\IntuneLaps.psd1
```

## Quick Start — CLI

```powershell
# Step 1: Authenticate
Connect-IntuneLaps

# Step 2: Search for a device
Find-IntuneLapsDevice -DeviceName 'DESKTOP-'

# Step 3: Get credentials (metadata only)
Get-IntuneLapsCredential -DeviceId '<device-id>'

# Step 4: Get credentials including password (requires elevated role)
Get-IntuneLapsCredential -DeviceId '<device-id>' -IncludePassword

# Pipeline support
Find-IntuneLapsDevice -DeviceName 'WS001' | Get-IntuneLapsCredential -IncludePassword

# Disconnect when done
Disconnect-IntuneLaps
```

## Quick Start — GUI

```powershell
Import-Module .\IntuneLaps.psd1
Show-IntuneLapsGui
```

## RBAC Permissions

| What you can do | Required Permission | Required Entra Role |
|---|---|---|
| Search Intune devices | `DeviceManagementManagedDevices.Read.All` | Intune Administrator |
| Read LAPS username / metadata | `DeviceLocalCredential.ReadBasic.All` | Helpdesk Admin, Security Reader |
| Read LAPS password | `DeviceLocalCredential.Read.All` | Cloud Device Admin, Intune Admin |

## Running Tests

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester -Path .\Tests\ -Output Detailed
```

## Graph API Endpoints Used

All endpoints are **GA (v1.0)** — no beta required.

| Action | Endpoint |
|---|---|
| Device search | `GET /deviceManagement/managedDevices?$filter=startsWith(deviceName,'...')` |
| LAPS metadata | `GET /directory/deviceLocalCredentials/{deviceId}` |
| LAPS + password | `GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials` |
