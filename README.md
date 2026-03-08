# IntuneLaps

A PowerShell module with WPF GUI for securely retrieving **Intune LAPS** (Local Administrator Password Solution) credentials via the Microsoft Graph API — no App Registration required.

## Features

- 🔍 **Device search** — find Intune-managed devices by name (prefix or exact match)
- ✅ **LAPS Active indicator** — see at a glance which devices have an active LAPS record
- 👤 **Username retrieval** — works with basic LAPS permissions
- 🔑 **Password retrieval** — requires elevated Entra role (Cloud Device Administrator / Intune Administrator)
- 👁 **Toggle visibility** — reveal or mask the password on demand
- 📋 **Copy buttons** — copy username or password to clipboard
- 🗑 **Auto-clear clipboard** — password is automatically cleared from clipboard after 30 seconds
- ⏳ **Progress feedback** — loading overlay in the GUI; progress bar in the CLI
- 🔄 **Throttle handling** — automatic retry on Graph API 429 responses
- 🌗 **Windows theme-aware** — GUI respects your dark/light mode setting
- ⌨️ **Dual-mode** — fully usable via CLI *and* WPF GUI

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- `Microsoft.Graph.Authentication` module ≥ 2.0.0 *(auto-installed on first run)*
- An Entra ID account with one of:
  - **Helpdesk Administrator** (or higher) — for username and metadata
  - **Cloud Device Administrator** or **Intune Administrator** — for password access

## Installation

```powershell
# Clone the repository
git clone https://github.com/0125joel/IntuneLaps.git
cd IntuneLaps

# Import the module (Graph dependency is auto-installed if missing)
Import-Module .\IntuneLaps.psd1
```

## Quick Start — GUI

```powershell
Import-Module .\IntuneLaps.psd1
Show-IntuneLapsGui
```

1. Click **Sign In** — authenticate with your Entra ID account
2. Devices load automatically — the **LAPS Active** column shows which ones have a LAPS record
3. Search by device name, select a row, click **Load Credentials**
4. Copy username or password — clipboard clears automatically after 30 seconds
5. Click **Sign Out** or close the window when done

## Quick Start — CLI

```powershell
# Authenticate
Connect-IntuneLaps

# Search devices by name prefix
Find-IntuneLapsDevice -DeviceName 'DESKTOP-'

# Exact match
Find-IntuneLapsDevice -DeviceName 'WS001' -ExactMatch

# Retrieve metadata only (username + backup date)
Get-IntuneLapsCredential -DeviceId '<azure-ad-device-id>'

# Retrieve full credentials including password (requires elevated role)
Get-IntuneLapsCredential -DeviceId '<azure-ad-device-id>' -IncludePassword

# Pipeline — find and retrieve in one line
Find-IntuneLapsDevice -DeviceName 'LAPTOP-HR01' | Get-IntuneLapsCredential -IncludePassword

# Disconnect when done
Disconnect-IntuneLaps
```

## RBAC Permissions

| What you can do | Required Graph Scope | Required Entra Role |
|---|---|---|
| Search Intune devices | `DeviceManagementManagedDevices.Read.All` | Intune Administrator |
| View username / metadata | `DeviceLocalCredential.ReadBasic.All` | Helpdesk Admin · Security Reader |
| View password | `DeviceLocalCredential.Read.All` | Cloud Device Admin · Intune Admin |

The module detects your permission level from the active Graph token and adapts accordingly — the password field and copy button are automatically disabled if your account lacks the required role.

## Multi-tenant / WAM SSO

Windows Web Account Manager silently re-authenticates using the cached default account. To connect to a different tenant, specify it explicitly:

```powershell
Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
```

## Running Tests

```powershell
Invoke-Pester .\Tests\IntuneLaps.Tests.ps1
```

## Graph API Endpoints Used

All endpoints are **GA (v1.0)** — no beta APIs required.

| Action | Endpoint |
|---|---|
| Device search | `GET /deviceManagement/managedDevices?$filter=startsWith(deviceName,'...')` |
| LAPS metadata | `GET /directory/deviceLocalCredentials/{deviceId}` |
| LAPS + password | `GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials` |
