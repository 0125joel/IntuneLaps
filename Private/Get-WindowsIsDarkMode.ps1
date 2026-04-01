function Get-WindowsIsDarkMode {
    <#
    .SYNOPSIS
        Returns $true when Windows is configured to use dark mode for apps.
    .DESCRIPTION
        Reads the AppsUseLightTheme registry value from the current user's
        personalisation settings. Defaults to $true (dark) when the key is absent
        or when an error occurs reading it.
    .OUTPUTS
        [bool]
    .EXAMPLE
        if (Get-WindowsIsDarkMode) { Set-WindowTheme -Window $Window -IsDark $true }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    process {
        try {
            [int]$Value = Get-ItemPropertyValue `
                -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
                -Name 'AppsUseLightTheme' `
                -ErrorAction SilentlyContinue
            return ($Value -eq 0)  # 0 = dark, 1 = light
        }
        catch {
            return $true  # default to dark
        }
    }
}
