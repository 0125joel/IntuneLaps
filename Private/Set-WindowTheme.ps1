function Set-WindowTheme {
    <#
    .SYNOPSIS
        Applies dark or light theme colours to a WPF Window's resource dictionary.
    .DESCRIPTION
        Updates the named brush resources (BackgroundBrush, SurfaceBrush, etc.) in
        the supplied WPF Window so that all bound controls reflect the chosen theme.
        Must be called after WPF assemblies have been loaded (i.e. from within
        Show-IntuneLapsGui after Add-Type calls).
    .PARAMETER Window
        The WPF Window object whose Resources dictionary will be updated.
    .PARAMETER IsDark
        When $true, applies the dark palette. When $false, applies the light palette.
    .EXAMPLE
        Set-WindowTheme -Window $Window -IsDark (Get-WindowsIsDarkMode)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Window,

        [Parameter(Mandatory = $true)]
        [bool]$IsDark
    )

    process {
        $Resources = $Window.Resources
        if ($IsDark) {
            $Resources['BackgroundBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x1E, 0x1E, 0x2E)
            $Resources['SurfaceBrush']    = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x2A, 0x2A, 0x3E)
            $Resources['SurfaceAltBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x31, 0x31, 0x47)
            $Resources['ForegroundBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xF0, 0xF0, 0xF0)
            $Resources['MutedBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x9A, 0x9A, 0xB0)
            $Resources['InputBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x25, 0x25, 0x38)
            $Resources['BorderBrush']     = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x3C, 0x3C, 0x5A)
        }
        else {
            $Resources['BackgroundBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xF5, 0xF5, 0xF5)
            $Resources['SurfaceBrush']    = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF)
            $Resources['SurfaceAltBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xEA, 0xEA, 0xF2)
            $Resources['ForegroundBrush'] = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x1E, 0x1E, 0x1E)
            $Resources['MutedBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x60, 0x60, 0x70)
            $Resources['InputBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF)
            $Resources['BorderBrush']     = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xCC, 0xCC, 0xDD)
        }
        $Window.Background = $Resources['BackgroundBrush']
    }
}
