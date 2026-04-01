# Changelog

## [1.1.0] - 2026-04-01

### Added

- Dual-gate permission model: effective access level is the lower of the API scope gate and the Entra role gate — both must qualify
- Role evaluation based on stable role template GUIDs instead of display names, making it immune to role renames
- Global Administrator now correctly grants Full access
- PIM-eligible role detection: if activating a PIM role would raise your access level, a hint is shown after sign-in
- Administrative Unit scoping detection: AU-scoped roles are reported and a hint is shown when a 403 is returned for a specific device
- `Get-IntuneLapsCredential` accepts `-DeviceName` directly — no separate `Find-IntuneLapsDevice` call needed
- Multiple LAPS accounts per device are all returned, sorted newest-first by backup date
- `Get-IntuneLapsCredential` result includes `IsPasswordExpired` — indicates whether the scheduled password rotation date has passed
- Dark mode support in the GUI — automatically follows the Windows system theme

### Changed

- `Connect-IntuneLaps` now returns a session object with `EffectiveLevel`, `ActiveRoles`, and `PimEligibleRoles` instead of a flat `PermissionLevel` and `Scopes` list
- `Get-IntuneLapsCredential` access level is now determined automatically by the session — no longer requires `-IncludePassword` to retrieve passwords
- `Get-IntuneLapsCredential` returns a `Credentials` array (each entry has `AccountName`, `AccountSid`, `Password`, `BackupDateTime`) instead of flat `AccountName`/`Password` fields
- `Find-IntuneLapsDevice` pagination now uses a shared `Invoke-MgGraphPagedRequest` helper

### Removed

- `-IncludePassword` parameter on `Get-IntuneLapsCredential` — access is determined by the session's effective level
- `Test-LapsPermission` internal function — replaced by the session model (`Build-LapsSession`, `Get-UserRoleInfo`)
