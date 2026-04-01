# IntuneLaps

IntuneLaps is a PowerShell module for helpdesk staff and administrators who need to look up Windows LAPS credentials for Intune-managed devices. It authenticates using your own Entra ID account — no App Registration or service principal required.

The module comes with a WPF desktop application for everyday use and a full set of CLI commands for scripting and automation.

## What it does

When you open the GUI, all your managed devices load automatically. A **LAPS Active** column shows at a glance which devices have a LAPS record. Select a device, click **Load Credentials**, and the username and password are retrieved based on your permissions. Passwords copied to clipboard are cleared automatically after 30 seconds.

From the CLI, `Get-IntuneLapsCredential` accepts a device name directly so you can look up credentials in one step. `Find-IntuneLapsDevice` is there when you want to search and inspect the device list first. Both commands use OData pagination so large environments are handled automatically.

A few other things the module handles for you:

- 🌗 The GUI adapts to your Windows dark or light mode setting
- 🔄 Graph API throttle responses (429) are retried automatically with exponential backoff
- 👁 Passwords can be toggled between masked and plain text in the GUI
- 🔑 PIM-eligible roles are detected after sign-in — if activating one would raise your access level, you get a hint

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- The `Microsoft.Graph.Authentication` module v2.0.0 or higher (installed automatically on first use)
- An Entra ID account with at least one qualifying role (see [Permissions](#permissions))

The GUI only runs on Windows. The CLI commands work on any platform that supports PowerShell.

## Installation

Install from the PowerShell Gallery:

```powershell
Install-Module -Name IntuneLaps
```

Or clone and import manually:

```powershell
git clone https://github.com/0125joel/IntuneLaps.git
cd IntuneLaps
Import-Module .\IntuneLaps.psd1
```

## Using the GUI

```powershell
Show-IntuneLapsGui
```

1. Click **Sign In** and authenticate with your Entra ID account. Already signed in via the CLI? The GUI reuses that session and skips the login prompt
2. All managed devices load automatically. The **LAPS Active** column is populated when your permission level is Full
3. Search by device name if needed, select a row, and click **Load Credentials**
4. The GUI shows the most recent credential. If a device has multiple LAPS accounts, use `Get-IntuneLapsCredential` from the CLI to retrieve all of them
5. Use the copy buttons for the username or password
6. Click **Sign Out** or close the window — either way the session ends and the clipboard is wiped

## Using the CLI

```powershell
# Sign in
Connect-IntuneLaps

# Get credentials by device name directly
Get-IntuneLapsCredential -DeviceName 'DESKTOP-001' -ExactMatch

# Or search by prefix — returns credentials for every matching device
Get-IntuneLapsCredential -DeviceName 'DESKTOP-'

# Or supply an Entra device object ID (GUID) directly — not the Intune device ID
Get-IntuneLapsCredential -DeviceId 'b465e4e8-e4e8-b465-e8e4-65b4e8e465b4'

# Password is included automatically when your permission level is Full.
# At Metadata level only the username and timestamps are returned.

# Use Find-IntuneLapsDevice when you want to inspect the device list first
Find-IntuneLapsDevice -DeviceName 'DESKTOP-'
Find-IntuneLapsDevice -DeviceName 'WS001' -ExactMatch

# Pipe directly into Get-IntuneLapsCredential
Find-IntuneLapsDevice -DeviceName 'LAPTOP-HR01' | Get-IntuneLapsCredential

# Sign out when done
Disconnect-IntuneLaps
```

## Commands

### Connect-IntuneLaps

Opens an interactive browser sign-in to Microsoft Graph. After authentication, evaluates your API scopes and Entra roles to determine your effective permission level. Warns you if access is restricted and hints at PIM activation if that would help.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-TenantId` | String | No | Entra tenant ID or domain. Useful when you have accounts in multiple tenants. |

### Find-IntuneLapsDevice

Searches for Intune-managed devices by name. Returns device objects that can be piped into `Get-IntuneLapsCredential`. Calling it without parameters returns all devices. A progress bar updates per page.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceName` | String | No | Device name or prefix. Uses a server-side `startsWith` filter. Omit to return all devices. |
| `-ExactMatch` | Switch | No | Requires an exact name match instead of a prefix search. |

### Get-IntuneLapsCredential

Retrieves the LAPS credential record for a device. The password is included automatically when your permission level is Full. At Metadata level, username and timestamps are returned but the password is not. Multiple LAPS accounts per device are all returned, sorted newest-first. The result includes an `IsPasswordExpired` field derived from `RefreshDateTime` — `$true` if the scheduled rotation date has passed, `$false` if it hasn't, `$null` if the field is absent.

Supply either `-DeviceName` (resolves the device internally) or `-DeviceId` (GUID, used when piping from `Find-IntuneLapsDevice`).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceName` | String | Yes* | Device name or prefix. Resolves devices internally — no separate `Find-IntuneLapsDevice` call needed. |
| `-ExactMatch` | Switch | No | Used with `-DeviceName`. Requires an exact name match. |
| `-DeviceId` | String | Yes* | Entra device object ID (GUID). Accepts pipeline input from `Find-IntuneLapsDevice`. |

*Supply one of `-DeviceName` or `-DeviceId`, not both.

### Disconnect-IntuneLaps

Terminates the active Microsoft Graph session. Takes no parameters.

### Show-IntuneLapsGui

Launches the WPF desktop application. If a Graph session is already active the GUI reuses it. Takes no parameters. Windows only.

## Permissions

The module uses delegated authentication only — it acts on behalf of the signed-in user.

Access is controlled by two independent gates. **Both** must qualify for an operation to succeed. The more restrictive gate wins.

| Access level | Required API scope | Required Entra role |
|---|---|---|
| **Full** — devices + username + password | `DeviceLocalCredential.Read.All` | Global Administrator, Cloud Device Administrator, or Intune Administrator |
| **Metadata** — devices + username only | `DeviceLocalCredential.ReadBasic.All` | Helpdesk Administrator, Security Administrator, Security Reader, or Global Reader |

Example: a user with `DeviceLocalCredential.Read.All` scope but only **Helpdesk Administrator** role gets **Metadata** level — the scope allows Full, but the role caps it at Metadata.

Device search requires `DeviceManagementManagedDevices.Read.All`. Role detection requires `RoleManagement.Read.Directory`. Both are requested automatically by `Connect-IntuneLaps`.

## Connecting to a different tenant

To sign in to a specific tenant instead of your default cached account:

```powershell
Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a full history of changes per release.

## Graph API endpoints

All endpoints use the Microsoft Graph v1.0 API. No beta APIs are used.

| Action | Endpoint |
|---|---|
| Device search | `GET /deviceManagement/managedDevices?$filter=startsWith(deviceName,'...')` |
| LAPS metadata | `GET /directory/deviceLocalCredentials/{deviceId}` |
| LAPS metadata + password | `GET /directory/deviceLocalCredentials/{deviceId}?$select=id,credentials` |
| LAPS status bulk check (GUI) | `GET /directory/deviceLocalCredentials?$select=id,deviceName` |
| Signed-in user object ID | `GET /me?$select=id` |
| Active role assignments | `GET /roleManagement/directory/roleAssignments?$filter=principalId eq '{userId}'&$expand=roleDefinition($select=id,displayName)` |
| PIM eligible role assignments | `GET /roleManagement/directory/roleEligibilityScheduleInstances?$filter=principalId eq '{userId}'&$expand=roleDefinition($select=id,displayName)` |
| Administrative Unit display name | `GET /directory/administrativeUnits/{auId}?$select=displayName` |

## Contributing

```powershell
# Run the test suite
Invoke-Pester .\Tests\IntuneLaps.Tests.ps1
```
