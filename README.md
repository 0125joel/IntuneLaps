# IntuneLaps

IntuneLaps is a PowerShell module that lets helpdesk staff and administrators look up Windows LAPS credentials for Intune-managed devices. It connects to the Microsoft Graph API using your own Entra ID account, so no App Registration or service principal is needed.

The module works both as a WPF desktop application and as a set of CLI commands, depending on what you prefer.

## What it does

The GUI loads all your managed devices on sign-in and shows a **LAPS Active** column so you immediately know which devices have a LAPS record. Select a device, click Load Credentials, and the username and password are retrieved based on your permissions. Copied passwords are automatically cleared from the clipboard after 30 seconds.

In the CLI, `Find-IntuneLapsDevice` supports prefix search and full pagination, with a built-in progress bar that updates per page. Results can be piped directly into `Get-IntuneLapsCredential`.

Other things worth mentioning:

- 🌗 The GUI follows your Windows dark or light mode setting
- 🔄 Graph API 429 throttle responses are handled automatically with exponential backoff
- 👁 Passwords can be toggled between masked and visible in the GUI

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- An Entra ID account with sufficient permissions (see the permissions section below)
- The `Microsoft.Graph.Authentication` module (version 2.0.0 or higher, installed automatically on first use)
- An Entra ID account with at least Helpdesk Administrator role to retrieve usernames and metadata, or Cloud Device Administrator / Intune Administrator to also retrieve passwords

The WPF GUI only runs on Windows. The CLI functions work on any platform that supports PowerShell.

## Installation

You can install IntuneLaps directly from the PowerShell Gallery:

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
4. Use the copy buttons to copy the username or password to clipboard
5. Click **Sign Out** or close the window when you are done

## Using the CLI

```powershell
# Sign in
Connect-IntuneLaps

# Search for devices by name prefix
Find-IntuneLapsDevice -DeviceName 'DESKTOP-'

# Or search for an exact match
Find-IntuneLapsDevice -DeviceName 'WS001' -ExactMatch

# Get username and metadata only
Get-IntuneLapsCredential -DeviceId '<azure-ad-device-id>'

# Get full credentials including the password
Get-IntuneLapsCredential -DeviceId '<azure-ad-device-id>' -IncludePassword

# Find a device and retrieve its credentials in one line
Find-IntuneLapsDevice -DeviceName 'LAPTOP-HR01' | Get-IntuneLapsCredential -IncludePassword

# Sign out when done
Disconnect-IntuneLaps
```

## Commands

### Connect-IntuneLaps

Opens an interactive browser sign-in to Microsoft Graph. If a session is already active it will be reused. Returns an object with the signed-in account, tenant ID and detected permission level.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-TenantId` | String | No | Entra tenant ID or domain name. Use this when you need to connect to a specific tenant instead of the default cached account. |

### Find-IntuneLapsDevice

Searches for Intune-managed devices by name. Results are returned as objects and can be piped directly into `Get-IntuneLapsCredential`. When called without parameters it returns all managed devices. A built-in progress bar shows loading status per page.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceName` | String | No | Device name or prefix to search for. Uses a server-side `startsWith` filter. Omit to return all devices. |
| `-ExactMatch` | Switch | No | When specified, requires an exact name match instead of a prefix search. |

### Get-IntuneLapsCredential

Retrieves the LAPS credential record for a device. Without `-IncludePassword` only the username and metadata are returned, which works with basic Helpdesk Administrator permissions. Adding `-IncludePassword` requires Cloud Device Administrator or Intune Administrator role.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-DeviceId` | String | Yes | The Azure AD device object ID (GUID). Accepts pipeline input from `Find-IntuneLapsDevice`. |
| `-IncludePassword` | Switch | No | When specified, also retrieves and decodes the LAPS password. Requires elevated permissions. |

### Disconnect-IntuneLaps

Terminates the active Microsoft Graph session. Takes no parameters.

### Show-IntuneLapsGui

Launches the WPF desktop application. If a Graph session is already active the GUI reuses it and loads devices immediately. Takes no parameters. Windows only.

## Permissions

The module uses delegated authentication only. It acts on behalf of the signed-in user and is limited to whatever that user is allowed to do.

| What you can do | Required Graph scope | Required Entra role |
|---|---|---|
| Search Intune devices | `DeviceManagementManagedDevices.Read.All` | Intune Administrator |
| View username and metadata | `DeviceLocalCredential.ReadBasic.All` | Helpdesk Administrator, Security Reader |
| View the password | `DeviceLocalCredential.Read.All` | Cloud Device Administrator, Intune Administrator |

The module checks the active token scopes after sign-in and adjusts the interface accordingly. If your account does not have password access, the password field and copy button are disabled automatically.

## Connecting to a different tenant

Windows Web Account Manager will silently re-authenticate using your default cached account. If you need to connect to a different tenant, pass the tenant ID explicitly:

```powershell
Connect-IntuneLaps -TenantId 'contoso.onmicrosoft.com'
```

## Running the tests

```powershell
Invoke-Pester .\Tests\IntuneLaps.Tests.ps1
```

## Graph API endpoints

All endpoints used are GA (v1.0). No beta APIs are required.

| Action | Endpoint |
|---|---|
| Device search | `GET /deviceManagement/managedDevices?$filter=startsWith(deviceName,'...')` |
| LAPS metadata | `GET /directory/deviceLocalCredentials/{deviceId}` |
| LAPS metadata and password | `GET /directory/deviceLocalCredentials/{deviceId}?$select=credentials` |
