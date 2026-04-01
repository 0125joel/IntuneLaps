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
- `Connect-IntuneLaps` returns a session object showing account, tenant, effective level, active roles, and PIM-eligible roles
- `Get-IntuneLapsCredential` result includes `IsPasswordExpired` — indicates whether the scheduled password rotation date has passed
- Graph API throttle responses (429) are retried automatically with exponential backoff

### Removed

- `-IncludePassword` parameter on `Get-IntuneLapsCredential` — the session's effective level determines what is returned automatically
