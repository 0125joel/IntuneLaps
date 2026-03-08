function Show-IntuneLapsGui {
    <#
    .SYNOPSIS
        Launches the IntuneLaps WPF graphical user interface.
    .DESCRIPTION
        Opens a Windows Presentation Foundation (WPF) window that allows the user
        to interactively sign in, search for Intune-managed devices, and retrieve
        LAPS credentials. The GUI respects the Windows dark/light mode setting.

        If already connected via Connect-IntuneLaps, the existing session is reused.
        Otherwise, clicking "Sign In" within the GUI will trigger authentication.
    .EXAMPLE
        Show-IntuneLapsGui
    #>
    [CmdletBinding()]
    param()

    begin {
        $ErrorActionPreference = 'Stop'

        # WPF is Windows-only. Fail gracefully on macOS/Linux with a clear message.
        if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
            Write-Warning 'Show-IntuneLapsGui is only supported on Windows (WPF not available on macOS/Linux).'
            Write-Host 'Use the CLI functions instead:'
            Write-Host '  Connect-IntuneLaps'
            Write-Host '  Find-IntuneLapsDevice -DeviceName <name>'
            Write-Host '  Get-IntuneLapsCredential -DeviceId <id> [-IncludePassword]'
            return
        }

        # WPF requires STA (Single Threaded Apartment) mode.
        # PowerShell 5.1 runs STA by default; PowerShell 7 (pwsh) runs MTA by default.
        # If we are in MTA, we must run the GUI on a new STA thread.
        [System.Threading.ApartmentState]$CurrentState = [System.Threading.Thread]::CurrentThread.GetApartmentState()
        if ($CurrentState -ne [System.Threading.ApartmentState]::STA) {
            Write-Verbose 'Running in MTA (PowerShell 7). Launching WPF GUI on a dedicated STA thread...'

            # Capture the manifest path before entering the thread — $PSCommandPath is $null inside a Thread scriptblock
            [string]$ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\IntuneLaps.psd1'
            $StaThread = [System.Threading.Thread]::new({
                Import-Module $ManifestPath -Force -ErrorAction Stop
                Show-IntuneLapsGui
            }.GetNewClosure())
            $StaThread.SetApartmentState([System.Threading.ApartmentState]::STA)
            $StaThread.IsBackground = $true
            $StaThread.Start()
            $StaThread.Join()   # Block the calling thread until the GUI closes
            return
        }

        # Load required WPF assemblies (STA thread confirmed)
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Xaml
    }

    process {
        # ─── Read XAML ────────────────────────────────────────────────────────────
        [string]$XamlPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Resources\MainWindow.xaml'
        if (-not (Test-Path -Path $XamlPath)) {
            throw "MainWindow.xaml not found at: $XamlPath"
        }

        [xml]$Xaml = Get-Content -Path $XamlPath -Raw -Encoding UTF8
        $Reader    = [System.Xml.XmlNodeReader]::new($Xaml)
        $Window    = [System.Windows.Markup.XamlReader]::Load($Reader)

        # ─── Detect Windows dark/light mode ───────────────────────────────────────
        function Get-WindowsIsDarkMode {
            try {
                [int]$Value = Get-ItemPropertyValue `
                    -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
                    -Name 'AppsUseLightTheme' `
                    -ErrorAction SilentlyContinue
                return ($Value -eq 0)  # 0 = dark, 1 = light
            }
            catch { return $true }  # default to dark
        }

        # Apply Windows theme-aware colours
        function Set-WindowTheme {
            param([bool]$IsDark)

            $Resources = $Window.Resources
            if ($IsDark) {
                $Resources['BackgroundBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x1E, 0x1E, 0x2E)
                $Resources['SurfaceBrush']     = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x2A, 0x2A, 0x3E)
                $Resources['SurfaceAltBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x31, 0x31, 0x47)
                $Resources['ForegroundBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xF0, 0xF0, 0xF0)
                $Resources['MutedBrush']       = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x9A, 0x9A, 0xB0)
                $Resources['InputBrush']       = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x25, 0x25, 0x38)
                $Resources['BorderBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x3C, 0x3C, 0x5A)
                $Window.Background             = $Resources['BackgroundBrush']
            }
            else {
                # Light mode
                $Resources['BackgroundBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xF5, 0xF5, 0xF5)
                $Resources['SurfaceBrush']     = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF)
                $Resources['SurfaceAltBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xEA, 0xEA, 0xF2)
                $Resources['ForegroundBrush']  = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x1E, 0x1E, 0x1E)
                $Resources['MutedBrush']       = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0x60, 0x60, 0x70)
                $Resources['InputBrush']       = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xFF, 0xFF, 0xFF)
                $Resources['BorderBrush']      = [System.Windows.Media.SolidColorBrush][System.Windows.Media.Color]::FromRgb(0xCC, 0xCC, 0xDD)
                $Window.Background             = $Resources['BackgroundBrush']
            }
        }

        Set-WindowTheme -IsDark (Get-WindowsIsDarkMode)

        # ─── Get named controls ────────────────────────────────────────────────────
        $TxtSearch         = $Window.FindName('TxtSearch')
        $BtnSearch         = $Window.FindName('BtnSearch')
        $BtnConnect        = $Window.FindName('BtnConnect')
        $BtnDisconnect     = $Window.FindName('BtnDisconnect')
        $GridDevices       = $Window.FindName('GridDevices')
        $LblSelectedDevice = $Window.FindName('LblSelectedDevice')
        $BtnGetCredentials = $Window.FindName('BtnGetCredentials')
        $TxtUsername       = $Window.FindName('TxtUsername')
        $BtnCopyUsername   = $Window.FindName('BtnCopyUsername')
        $PwdPassword       = $Window.FindName('PwdPassword')
        $TxtPassword       = $Window.FindName('TxtPassword')
        $BtnTogglePassword = $Window.FindName('BtnTogglePassword')
        $BtnCopyPassword   = $Window.FindName('BtnCopyPassword')
        $LblStatus         = $Window.FindName('LblStatus')
        $LblPermissionLevel= $Window.FindName('LblPermissionLevel')

        # ─── Internal state ────────────────────────────────────────────────────────
        [bool]$script:PasswordVisible  = $false
        [string]$script:PlainPassword  = $null
        [System.Windows.Threading.DispatcherTimer]$script:ClipTimer = $null

        # ─── Helper: update status bar ────────────────────────────────────────────
        function Update-Status {
            param([string]$Text, [string]$Level = '')
            $LblStatus.Text = $Text
            if ($Level -eq 'Full') {
                $LblPermissionLevel.Text       = '[OK] Full access (username + password)'
                $LblPermissionLevel.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x10, 0x7C, 0x10))
            }
            elseif ($Level -eq 'Metadata') {
                $LblPermissionLevel.Text       = '[!] Metadata only (no password access)'
                $LblPermissionLevel.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xCA, 0x75, 0x00))
            }
            else {
                $LblPermissionLevel.Text = ''
            }
        }

        # ─── Helper: clipboard auto-clear timer ───────────────────────────────────
        function Start-ClipboardClearTimer {
            param([int]$Seconds = 30)
            if ($script:ClipTimer) {
                $script:ClipTimer.Stop()
                $script:ClipTimer = $null
            }
            $script:ClipTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $script:ClipTimer.Interval = [TimeSpan]::FromSeconds($Seconds)
            $script:ClipTimer.Add_Tick({
                [System.Windows.Clipboard]::Clear()
                $script:ClipTimer.Stop()
                $script:ClipTimer = $null
                Update-Status "Clipboard cleared automatically after $Seconds seconds."
            })
            $script:ClipTimer.Start()
        }

        # ─── Helper: Get all device names that have a LAPS record ───────────────
        function Get-LapsActiveDeviceNames {
            # Returns a case-insensitive HashSet of deviceNames with LAPS records,
            # or $null if the call fails (e.g. insufficient permissions).
            $LapsNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            try {
                [string]$Uri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials?`$select=id,deviceName"
                do {
                    $Response = Invoke-MgGraphRequestWithRetry -Parameters @{ Method = 'GET'; Uri = $Uri }
                    if ($Response.value) {
                        foreach ($Entry in $Response.value) {
                            if (-not [string]::IsNullOrEmpty($Entry.deviceName)) {
                                $null = $LapsNames.Add($Entry.deviceName)
                            }
                        }
                    }
                    $Uri = $Response.'@odata.nextLink'
                } while ($Uri)
                return $LapsNames
            }
            catch {
                Write-Verbose "Could not retrieve LAPS device list: $_"
                return $null
            }
        }

        # ─── Helper: Search Devices ───────────────────────────────────────────────
        function Invoke-DeviceSearch {
            [string]$Query = $TxtSearch.Text.Trim()

            if ($Query) {
                Update-Status "Searching for devices matching '$Query'..."
            } else {
                Update-Status 'Fetching all managed devices...'
            }

            $GridDevices.ItemsSource = $null
            $BtnGetCredentials.IsEnabled = $false
            $LblSelectedDevice.Text = 'Searching...'

            try {
                if ($Query) {
                    [System.Collections.Generic.List[PSCustomObject]]$Devices = Find-IntuneLapsDevice -DeviceName $Query
                } else {
                    [System.Collections.Generic.List[PSCustomObject]]$Devices = Find-IntuneLapsDevice
                }

                if ($null -eq $Devices -or $Devices.Count -eq 0) {
                    if ($Query) {
                        Update-Status "No devices found for '$Query'."
                    } else {
                        Update-Status 'No Intune-managed devices found in the tenant.'
                    }
                    $LblSelectedDevice.Text = 'No results'
                    return
                }

                # Enrich each device with LAPS Active status via a single bulk call
                $LapsActiveNames = Get-LapsActiveDeviceNames
                $EnrichedDevices = @(foreach ($Dev in $Devices) {
                    [PSCustomObject]@{
                        DeviceId         = $Dev.DeviceId
                        DeviceName       = $Dev.DeviceName
                        OperatingSystem  = $Dev.OperatingSystem
                        OsVersion        = $Dev.OsVersion
                        ManagementState  = $Dev.ManagementState
                        LastSyncDateTime = $Dev.LastSyncDateTime
                        LapsActive       = if ($null -eq $LapsActiveNames) { '?' }
                                           elseif ($LapsActiveNames.Contains($Dev.DeviceName)) { 'Yes' }
                                           else { 'No' }
                    }
                })
                $GridDevices.ItemsSource = $EnrichedDevices
                Update-Status "$($Devices.Count) device(s) found. Select a device below."
                $LblSelectedDevice.Text = '- select a device'
            }
            catch {
                Update-Status "Search failed: $_"
            }
        }

        # ─── EVENT: Sign In ───────────────────────────────────────────────────────
        $BtnConnect.Add_Click({
            Update-Status 'Signing in to Microsoft Graph...'
            try {
                $ConnectResult = Connect-IntuneLaps
                [string]$Level = $ConnectResult.PermissionLevel

                Update-Status "Signed in as: $($ConnectResult.Account)" -Level $Level
                $BtnSearch.IsEnabled = $true
                $BtnDisconnect.IsEnabled = $true
                Invoke-DeviceSearch
            }
            catch {
                Update-Status "Sign in failed: $_"
            }
        })

        # ─── EVENT: Sign Out ──────────────────────────────────────────────────────
        $BtnDisconnect.Add_Click({
            Update-Status 'Signing out...'
            try {
                Disconnect-IntuneLaps -ErrorAction SilentlyContinue
                Update-Status 'Not connected - click Sign In to authenticate'
                $BtnSearch.IsEnabled = $false
                $BtnDisconnect.IsEnabled = $false
                $GridDevices.ItemsSource = $null
                $LblSelectedDevice.Text = '- select a device'
                $BtnGetCredentials.IsEnabled = $false
                $TxtUsername.Text = ''
                $PwdPassword.Password = ''
                $TxtPassword.Text = ''
                $script:PlainPassword = $null
            }
            catch {
                Update-Status "Sign out failed: $_"
            }
        })

        # ─── EVENT: Search ────────────────────────────────────────────────────────
        $BtnSearch.Add_Click({
            Invoke-DeviceSearch
        })

        # Support pressing Enter in search box
        $TxtSearch.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Return) {
                $BtnSearch.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            }
        })

        # ─── EVENT: Device row selected ───────────────────────────────────────────
        $GridDevices.Add_SelectionChanged({
            if ($null -ne $GridDevices.SelectedItem) {
                [string]$Name = $GridDevices.SelectedItem.DeviceName
                $LblSelectedDevice.Text = "- $Name"
                $BtnGetCredentials.IsEnabled = $true
                # Clear previous credentials
                $TxtUsername.Text     = ''
                $PwdPassword.Password = ''
                $TxtPassword.Text     = ''
                $script:PlainPassword = $null
                $BtnCopyUsername.IsEnabled  = $false
                $BtnCopyPassword.IsEnabled  = $false
                $BtnTogglePassword.IsEnabled = $false
            }
        })

        # ─── EVENT: Load Credentials ──────────────────────────────────────────────
        $BtnGetCredentials.Add_Click({
            if ($null -eq $GridDevices.SelectedItem) { return }

            [string]$DeviceId = $GridDevices.SelectedItem.DeviceId
            [string]$Level    = Test-LapsPermission
            [bool]$CanReadPassword = ($Level -eq 'Full')

            Update-Status 'Retrieving LAPS credentials...'

            try {
                $Cred = Get-IntuneLapsCredential -DeviceId $DeviceId -IncludePassword:$CanReadPassword

                if ($null -eq $Cred) {
                    Update-Status 'No LAPS record found for this device. Ensure LAPS is configured and the device has checked in recently.'
                    return
                }

                $TxtUsername.Text = $Cred.AccountName
                $BtnCopyUsername.IsEnabled = (-not [string]::IsNullOrEmpty($Cred.AccountName))

                if ($CanReadPassword -and $Cred.PasswordRetrieved) {
                    $script:PlainPassword = $Cred.Password
                    $PwdPassword.Password = $Cred.Password
                    $TxtPassword.Text     = $Cred.Password
                    $BtnCopyPassword.IsEnabled   = $true
                    $BtnTogglePassword.IsEnabled = $true
                    Update-Status "Credentials loaded for: $($Cred.DeviceName)" -Level $Level
                }
                else {
                    $PwdPassword.Password = ''
                    $TxtPassword.Text     = ''
                    $script:PlainPassword = $null
                    $BtnCopyPassword.IsEnabled   = $false
                    $BtnTogglePassword.IsEnabled = $false

                    if (-not $CanReadPassword) {
                        Update-Status "Username loaded. Password unavailable - your account lacks 'Cloud Device Administrator' or 'Intune Administrator' role." -Level $Level
                    }
                    else {
                        Update-Status "Credentials loaded (no password record found)." -Level $Level
                    }
                }
            }
            catch {
                Update-Status "Failed to load credentials: $_"
            }
        })

        # ─── EVENT: Toggle password visibility ────────────────────────────────────
        $BtnTogglePassword.Add_Click({
            $script:PasswordVisible = -not $script:PasswordVisible

            if ($script:PasswordVisible) {
                $PwdPassword.Visibility = [System.Windows.Visibility]::Collapsed
                $TxtPassword.Visibility = [System.Windows.Visibility]::Visible
                $Window.FindName('TxtToggleIcon').Text = '[Hide]'
            }
            else {
                $TxtPassword.Visibility = [System.Windows.Visibility]::Collapsed
                $PwdPassword.Visibility = [System.Windows.Visibility]::Visible
                $Window.FindName('TxtToggleIcon').Text = '[Show]'
            }
        })

        # ─── EVENT: Copy Username ─────────────────────────────────────────────────
        $BtnCopyUsername.Add_Click({
            if (-not [string]::IsNullOrEmpty($TxtUsername.Text)) {
                [System.Windows.Clipboard]::SetText($TxtUsername.Text)
                Update-Status 'Username copied to clipboard.'
            }
        })

        # ─── EVENT: Copy Password ─────────────────────────────────────────────────
        $BtnCopyPassword.Add_Click({
            if (-not [string]::IsNullOrEmpty($script:PlainPassword)) {
                [System.Windows.Clipboard]::SetText($script:PlainPassword)
                Update-Status 'Password copied to clipboard - will be cleared in 30 seconds.'
                Start-ClipboardClearTimer -Seconds 30
            }
        })

        # ─── Check existing Graph session on open ─────────────────────────────────
        $Window.Add_Loaded({
            try {
                $Ctx = Get-MgContext -ErrorAction SilentlyContinue
                if ($Ctx) {
                    [string]$Level = Test-LapsPermission
                    Update-Status "Already signed in as: $($Ctx.Account)" -Level $Level
                    $BtnSearch.IsEnabled = $true
                    $BtnDisconnect.IsEnabled = $true
                    Invoke-DeviceSearch
                }
                else {
                    Update-Status 'Not connected - click Sign In to authenticate.'
                    $BtnSearch.IsEnabled = $false
                    $BtnDisconnect.IsEnabled = $false
                }
            }
            catch {
                Update-Status 'Not connected - click Sign In to authenticate.'
                $BtnSearch.IsEnabled = $false
                $BtnDisconnect.IsEnabled = $false
            }
        })

        # ─── Clear clipboard and disconnect on window close ──────────────────────
        $Window.Add_Closing({
            if ($script:ClipTimer) { $script:ClipTimer.Stop() }
            [System.Windows.Clipboard]::Clear()
            Disconnect-IntuneLaps -ErrorAction SilentlyContinue
        })

        # ─── Show the window ──────────────────────────────────────────────────────
        $null = $Window.ShowDialog()
    }
}
