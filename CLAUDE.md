# CLAUDE.md - IntuneLaps Agent Context & Project History

## Core Objective
IntuneLaps is a PowerShell module with a WPF desktop GUI that allows helpdesk staff and admins to search for Intune-managed devices and securely retrieve their LAPS local admin username and/or password — using their own Entra ID credentials (delegated auth, no App Registration required).

## Tech Stack & Dependencies
- **Languages:** PowerShell (v5.1 native & v7+ cross-platform)
- **UI:** WPF (Windows Presentation Foundation) - Windows Only
- **Dependencies:** `Microsoft.Graph.Authentication` module
- **Testing:** Pester v3.4.0 (Must maintain v3 syntax for Windows native support)
- **API Endpoint:** Microsoft Graph API v1.0 (GA)

## Architecture & Project Structure
- `IntuneLaps.psd1` & `.psm1`: Module manifest and root loader. The `.psm1` handles auto-bootstrapping of the Graph module and dot-sources the `Public/` and `Private/` folders.
- `Public/`: Exported functions.
  - `Connect-IntuneLaps.ps1`: Wraps `Connect-MgGraph` interactively.
  - `Disconnect-IntuneLaps.ps1`: Cleans up the Graph session.
  - `Find-IntuneLapsDevice.ps1`: Server-side OData limit device search.
  - `Get-IntuneLapsCredential.ps1`: LAPS metadata/password retrieval.
  - `Show-IntuneLapsGui.ps1`: WPF GUI launcher.
- `Private/`: Internal module helpers.
  - `ConvertFrom-LapsPassword.ps1`: Decodes Base64 UTF-16LE LAPS passwords.
  - `Test-LapsPermission.ps1`: Checks active Graph token scopes.
- `Resources/MainWindow.xaml`: WPF layout (supports dynamic dark/light theme).
- `Tests/IntuneLaps.Tests.ps1`: Unit tests for core functions.

## Commands
- **Test:** `Invoke-Pester .\Tests\IntuneLaps.Tests.ps1` (Tests are v3.4.0 compatible)
- **Reload:** `Remove-Module IntuneLaps -ErrorAction SilentlyContinue; Import-Module .\IntuneLaps.psd1 -Force`
- **Start GUI:** `Show-IntuneLapsGui`

## RBAC Security Model
The tool relies purely on the user's delegated Graph API permissions. It strictly enforces RBAC logic based on the returned token `$Context.Scopes`:
- **Helpdesk Admin, Security Reader** (`DeviceLocalCredential.ReadBasic.All` scope): Can view the username (`accountName`), backup date, and device metadata. The GUI will gracefully disable the password toggle and show an "Insufficient permissions" warning.
- **Cloud Device Admin, Intune Admin** (`DeviceLocalCredential.Read.All` scope): Can view both metadata and the actual password.

## Code Style, Bugs, & Critical Conventions
- **No MgContext Types:** DO NOT use explicit type casting for `[Microsoft.Graph.PowerShell.Authentication.MgContext]`. PowerShell 5.1 fails to find this type on initial load before the accelerator runs, causing fatal crashes. Use untyped variables (e.g., `$Context = Get-MgContext`).
- **Pester v3 Syntax ONLY:** Tests must conform to Pester v3.4.0 (Windows 10/11 default native). Use `Should Be` (not `Should -Be`). For variables injected into `Mock` blocks, bypass dynamic scope issues by hardcoding literals or using explicitly scoped `$Script:` variables, as v3 handles module scopes differently than v5.
- **WPF Threading (MTA vs STA):** PowerShell 7 defaults to MTA. The `Show-IntuneLapsGui` function spins up a dedicated `[System.Threading.Thread]` with `[System.Threading.ApartmentState]::STA` to host the UI, importing the module internally in the thread. Do not alter this thread initialization.
- **OS Guards:** WPF is Windows-only. The GUI function contains a platform guard `if ($IsLinux -or $IsMacOS)` at the top to exit gracefully and instruct use of CLI features. Keep this intact.
- **Graph API Quirks:** 
  1. The v1.0 `managedDevices` endpoint throws a 400 Bad Request if you `$select` the `joinType` property. Do not attempt to retrieve `joinType` in OData queries.
  2. LAPS passwords are returned encoded in Base64 UTF-16LE. They must be decoded natively via `[System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($pwd))`.
- **WAM / Tenant SSO:** Windows WAM prevents tenant switching by silently re-authenticating the default cached user. Users experiencing this loop must run `Connect-IntuneLaps -TenantId "<domain>"` in the CLI to force a tenant switch before starting the GUI.
- **GUI Auto-Load:** The `Find-IntuneLapsDevice` function allows empty searches. The GUI automatically fetches and lists all devices immediately upon Sign In or window open.

## Security & Cleanup
- The GUI includes a Sign Out button AND hooks into the natively closed `Window.Add_Closing` event. Both fire `Disconnect-IntuneLaps` to securely tear down the Graph session.
- Passwords copied to the clipboard use a `System.Windows.Threading.DispatcherTimer` to auto-clear after 30 seconds to prevent lingering sensitive data.
