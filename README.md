# IntuneLaps

IntuneLaps is a PowerShell module for helpdesk staff and administrators who need to look up Windows LAPS credentials for Intune-managed devices. It authenticates using your own Entra ID account, so there is no need for an App Registration or service principal.

The module comes with a WPF desktop application for everyday use and a full set of CLI commands for scripting and automation.

## What it does

When you open the GUI, all your managed devices load automatically. A **LAPS Active** column shows at a glance which devices have a LAPS record. Select a device, click **Load Credentials**, and the username and password are retrieved based on your role. Passwords copied to clipboard are cleared automatically after 30 seconds.

From the CLI, `Find-IntuneLapsDevice` searches by name prefix with full OData pagination and a progress bar that updates per page. Results pipe directly into `Get-IntuneLapsCredential`.

A few other things the module handles for you:

- 🌗 The GUI adapts to your Windows dark or light mode setting
- 🔄 Graph API throttle responses (429) are retried automatically with exponential backoff
- 👁 Passwords can be toggled between masked and plain text in the GUI

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- The `Microsoft.Graph.Authentication` module version 2.0.0 or higher (installed automatically on first use)
- An Entra ID account with at least Helpdesk Administrator role to retrieve usernames and metadata, or Cloud Device Administrator / Intune Administrator to also retrieve passwords

The GUI only runs on Windows. The CLI commands work on any platform that supports PowerShell.

## Installation

Install from the PowerShell Gallery:

```powershell
Install-Module -Name IntuneLaps
```

Or clone the repository and import it manually:

```powershell
git clone https://github.com/0125joel/IntuneLaps.git
cd IntuneLaps
Import-Module .\IntuneLaps.psd1
```

## Using the GUI

```powershell
Show-IntuneLapsGui
```

1. Click **Sign In** and authenticate with your Entra ID account
2. All managed devices load automatically with their LAPS status
3. Search by device name if needed, select a row, and click **Load Credentials**
4. Use the copy buttons for the username or password
5. Click **Sign Out** or close the window when you are done

## Using the CLI

```powershell
# Sign in
Connect-IntuneLaps

# Search by name prefix
Find-IntuneLapsDevice -DeviceName 'DESKTOP-'

# Or require an exact match
Find-IntuneLapsDevice -DeviceName 'WS001' -ExactMatch

# Get username and metadata only
Get-IntuneLapsCredential -DeviceId '<entra-id-device-id>'

# Get full credentials including the password
Get-IntuneLapsCredential -DeviceId '<entra-id-device-id>' -IncludePassword

# Find and retrieve credentials in one line
Find-IntuneLapsDevice -DeviceName 'LAPTOP-HR01' | Get-IntuneLapsCredential -IncludePassword

# Sign out when done
Disconnect-IntuneLaps
```

## Commands

### Connect-IntuneLaps

Opens an interactive browser sign-in to Microsoft Graph. If a session is already active it will be reused. Returns an object with the signed-in account, tenant ID and detected permission level.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-TenantId` | String | No | Entra tenant ID or domain name. Use this to connect to a specific tenant instead of the default cached account. |

### Find-IntuneLapsDevice

Searches for Intune-managed devices by name. Returns objects that can be piped into `Get-IntuneLapsCredential`. Calling it without parameters returns all devices. A progress bar shows how many devices have been loaded per page.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceName` | String | No | Device name or prefix to search for. Uses a server-side `startsWith` filter. Omit to return all devices. |
| `-ExactMatch` | Switch | No | Requires an exact name match instead of a prefix search. |

### Get-IntuneLapsCredential

Retrieves the LAPS credential record for a device. Without `-IncludePassword` only the username and metadata are returned, which works with Helpdesk Administrator permissions. Adding `-IncludePassword` requires Cloud Device Administrator or Intune Administrator role.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceId` | String | Yes | The Entra ID device object ID (GUID). Accepts pipeline input from `Find-IntuneLapsDevice`. |
| `-IncludePassword` | Switch | No | Also retrieves and decodes the LAPS password. Requires elevated permissions. |

### Disconnect-IntuneLaps

Terminates the active Microsoft Graph session. Takes no parameters.

### Show-IntuneLapsGui

Launches the WPF desktop application. If a Graph session is already active the GUI reuses it and loads devices immediately. Takes no parameters. Windows only.

## Permissions

The module uses delegated authentication only. It acts on behalf of the signed-in user and is limited to what that user is allowed to do in Entra.

| What you can do | Required Graph scope | Required Entra role |
|---|---|---|
| Search Intune devices | `DeviceManagementManagedDevices.Read.All` | Intune Administrator |
| View username and metadata | `DeviceLocalCredential.ReadBasic.All` | Helpdesk Administrator, Security Reader |
| View the password | `DeviceLocalCredential.Read.All` | Cloud Device Administrator, Intune Administrator |

The module checks token scopes after sign-in and adjusts the interface accordingly. If your account does not have password access, the password field and copy button are disabled automatically.

## Connecting to a different tenant

Windows Web Account Manager re-authenticates silently using your default cached account. To connect to a different tenant, pass the tenant ID explicitly:

```powershell
Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
```

## Running the tests

```powershell
Invoke-Pester .\Tests\IntuneLaps.Tests.ps1
```

## Graph API endpoints

All endpoints are GA (v1.0). No beta APIs are used.

| Action | Endpoint |
|---|---|
| Device search | `GET /deviceManagement/managedDevices?$filter=startsWith(deviceName,'...')` |
| LAPS metadata | `GET /directory/deviceLocalCredentials/{deviceId}` |
| LAPS metadata and password | `GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials` |
