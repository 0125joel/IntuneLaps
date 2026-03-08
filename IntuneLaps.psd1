@{
    # Module metadata
    RootModule        = 'IntuneLaps.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a3f7c8d1-5e2b-4a9f-b6c3-8d1e0f2a4b5c'
    Author            = 'Joel'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Joel. MIT License.'
    Description       = 'Retrieve Intune LAPS local admin credentials (username and password) via Microsoft Graph API with CLI and WPF GUI support.'

    # Requirements
    PowerShellVersion = '5.1'

    # Exported functions (Public only)
    FunctionsToExport = @(
        'Connect-IntuneLaps'
        'Find-IntuneLapsDevice'
        'Get-IntuneLapsCredential'
        'Show-IntuneLapsGui'
        'Disconnect-IntuneLaps'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags       = @('Intune', 'LAPS', 'Graph', 'Security', 'WPF')
            ProjectUri = 'https://github.com/0125joel/IntuneLaps'
        }
    }
}
