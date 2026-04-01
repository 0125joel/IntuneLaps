function Show-IntuneLapsGui {
    <#
    .SYNOPSIS
        Launches the IntuneLaps WPF graphical user interface.
    .DESCRIPTION
        Opens a Windows Presentation Foundation (WPF) window that allows the user
        to interactively sign in, search for Intune-managed devices, and retrieve
        LAPS credentials. The GUI respects the Windows dark/light mode setting.

        If already connected via Connect-IntuneLaps, the existing session is reused
        without re-authenticating. The [LapsSession] singleton is reconstructed on
        the STA thread via Build-LapsSession (WPF STA threads have their own module
        scope and do not inherit $script:CurrentSession from the calling thread).
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
            Write-Warning 'Use the CLI functions instead: Connect-IntuneLaps | Find-IntuneLapsDevice -DeviceName <name> | Get-IntuneLapsCredential -DeviceId <id>'
            return
        }

        # WPF requires STA (Single Threaded Apartment) mode.
        # PowerShell 5.1 runs STA by default; PowerShell 7 (pwsh) runs MTA by default.
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
            $StaThread.Join()
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

        Set-WindowTheme -Window $Window -IsDark (Get-WindowsIsDarkMode)

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
        $PrgLoading        = $Window.FindName('PrgLoading')
        $PnlLoading        = $Window.FindName('PnlLoading')
        $TxtLoadingStatus  = $Window.FindName('TxtLoadingStatus')

        # ─── Internal state hashtable ─────────────────────────────────────────────
        # Reference type: all event handler closures share the same object.
        $State = @{
            PasswordVisible = $false
            PlainPassword   = [string]$null
            ClipTimer       = $null
            Session         = $null    # [LapsSession]
        }

        # ─── Helper: update status bar ────────────────────────────────────────────
        function Update-Status {
            param([string]$Text, [LapsPermissionLevel]$Level = [LapsPermissionLevel]::None)
            $LblStatus.Text = $Text

            if ($Level -eq [LapsPermissionLevel]::Full) {
                $DisplayNames = if ($State.Session -and $State.Session.ActiveRoles.Count -gt 0) {
                    $AuRoleNames = @($State.Session.AuScopedRoles | ForEach-Object { $_.RoleName })
                    $State.Session.ActiveRoles | ForEach-Object {
                        if ($AuRoleNames -contains $_) { "$_ (AU-scoped)" } else { $_ }
                    }
                } else { $null }
                $LblPermissionLevel.Text = if ($DisplayNames) {
                    "[OK] Full access — $($DisplayNames -join ', ')"
                } else {
                    '[OK] Full access'
                }
                $LblPermissionLevel.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.Color]::FromRgb(0x10, 0x7C, 0x10))
            }
            elseif ($Level -eq [LapsPermissionLevel]::Metadata) {
                $RoleNames = if ($State.Session -and $State.Session.ActiveRoles.Count -gt 0) {
                    $State.Session.ActiveRoles -join ', '
                } else { $null }
                $LblPermissionLevel.Text = if ($State.Session -and $State.Session.PimEligibleRoles.Count -gt 0) {
                    '[!] Metadata only — activate PIM role for full access'
                } elseif ($RoleNames) {
                    "[!] Metadata only — $RoleNames"
                } else {
                    '[!] Metadata only (no password access)'
                }
                $LblPermissionLevel.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.Color]::FromRgb(0xCA, 0x75, 0x00))
            }
            else {
                # None or no level provided
                if ($State.Session -and $State.Session.PimEligibleRoles.Count -gt 0) {
                    $LblPermissionLevel.Text = '[!] No active LAPS role — PIM-eligible roles detected, activate first'
                } elseif ($Text -ne '') {
                    $LblPermissionLevel.Text = '[x] No LAPS permissions'
                } else {
                    $LblPermissionLevel.Text = ''
                }
                $LblPermissionLevel.Foreground = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.Color]::FromRgb(0xC4, 0x2B, 0x1C))
            }
        }

        # ─── Helper: clipboard auto-clear timer ───────────────────────────────────
        function Start-ClipboardClearTimer {
            param([int]$Seconds = 30)
            if ($State.ClipTimer) {
                $State.ClipTimer.Stop()
                $State.ClipTimer = $null
            }
            $State.ClipTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $State.ClipTimer.Interval = [TimeSpan]::FromSeconds($Seconds)
            $State.ClipTimer.Add_Tick({
                [System.Windows.Clipboard]::Clear()
                $State.ClipTimer.Stop()
                $State.ClipTimer = $null
                Update-Status "Clipboard cleared automatically after $Seconds seconds."
            })
            $State.ClipTimer.Start()
        }

        # ─── Helper: force WPF to process pending render/layout work ─────────────
        function Invoke-DispatcherFlush {
            $Window.Dispatcher.Invoke(
                [Action]{},
                [System.Windows.Threading.DispatcherPriority]::Background
            )
        }

        # ─── Helper: Search Devices ───────────────────────────────────────────────
        function Invoke-DeviceSearch {
            [string]$Query = $TxtSearch.Text.Trim()

            $GridDevices.ItemsSource     = $null
            $BtnGetCredentials.IsEnabled = $false
            $LblSelectedDevice.Text      = 'Searching...'
            $PnlLoading.Visibility       = [System.Windows.Visibility]::Visible
            $TxtLoadingStatus.Text       = 'Loading devices...'
            $PrgLoading.Visibility       = [System.Windows.Visibility]::Visible

            if ($Query) {
                Update-Status "Searching for devices matching '$Query'..."
            } else {
                Update-Status 'Fetching all managed devices...'
            }
            Invoke-DispatcherFlush

            try {
                [string]$SelectFields = 'id,azureADDeviceId,deviceName,operatingSystem,osVersion,lastSyncDateTime,managementState'
                if ($Query) {
                    [string]$SafeQuery = $Query -replace "'", "''"
                    [string]$DeviceUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=startsWith(deviceName,'$SafeQuery')&`$select=$SelectFields"
                } else {
                    [string]$DeviceUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$SelectFields"
                }

                $RawDevices = Invoke-MgGraphPagedRequest -Uri $DeviceUri -OnPageLoaded {
                    param([int]$Count)
                    $TxtLoadingStatus.Text = "Loading devices... ($Count loaded)"
                    Invoke-DispatcherFlush
                }

                if ($RawDevices.Count -eq 0) {
                    $PnlLoading.Visibility = [System.Windows.Visibility]::Collapsed
                    $PrgLoading.Visibility = [System.Windows.Visibility]::Collapsed
                    if ($Query) {
                        Update-Status "No devices found for '$Query'."
                    } else {
                        Update-Status 'No Intune-managed devices found in the tenant.'
                    }
                    $LblSelectedDevice.Text = 'No results'
                    return
                }

                # ── Enrich with LAPS Active status ─────────────────────────────────
                # Only attempt the bulk call when EffectiveLevel = Full.
                # The /directory/deviceLocalCredentials endpoint requires Read.All scope;
                # attempting it with Metadata level causes a 403 storm.
                [int]$TotalDevices = $RawDevices.Count
                $TxtLoadingStatus.Text = "Checking LAPS status for $TotalDevices device(s)..."
                Invoke-DispatcherFlush

                $LapsActiveNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                [bool]$LapsLookupSucceeded = $false

                if ($State.Session -and $State.Session.EffectiveLevel -eq [LapsPermissionLevel]::Full) {
                    try {
                        [string]$LapsUri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials?`$select=id,deviceName"
                        $LapsEntries = Invoke-MgGraphPagedRequest -Uri $LapsUri
                        foreach ($Entry in $LapsEntries) {
                            if (-not [string]::IsNullOrEmpty($Entry.deviceName)) {
                                $null = $LapsActiveNames.Add($Entry.deviceName)
                            }
                        }
                        $LapsLookupSucceeded = $true
                    }
                    catch {
                        Write-Verbose "Could not retrieve LAPS device list: $_"
                    }
                }

                $EnrichedDevices = @(foreach ($Dev in $RawDevices) {
                    [PSCustomObject]@{
                        DeviceId         = $Dev.azureADDeviceId
                        DeviceName       = $Dev.deviceName
                        OperatingSystem  = $Dev.operatingSystem
                        OsVersion        = $Dev.osVersion
                        ManagementState  = $Dev.managementState
                        LastSyncDateTime = $Dev.lastSyncDateTime
                        LapsActive       = if ($State.Session -and $State.Session.EffectiveLevel -ne [LapsPermissionLevel]::Full) { 'N/A' }
                                           elseif (-not $LapsLookupSucceeded) { '?' }
                                           elseif ($LapsActiveNames.Contains($Dev.deviceName)) { 'Yes' }
                                           else { 'No' }
                    }
                })

                $GridDevices.ItemsSource = $EnrichedDevices
                $PnlLoading.Visibility   = [System.Windows.Visibility]::Collapsed
                $PrgLoading.Visibility   = [System.Windows.Visibility]::Collapsed
                Update-Status "$TotalDevices device(s) found."
                $LblSelectedDevice.Text  = '- select a device'
            }
            catch {
                $PnlLoading.Visibility = [System.Windows.Visibility]::Collapsed
                $PrgLoading.Visibility = [System.Windows.Visibility]::Collapsed
                Update-Status "Search failed: $_"
                $LblSelectedDevice.Text = '- select a device'
            }
        }

        # ─── EVENT: Sign In ───────────────────────────────────────────────────────
        $BtnConnect.Add_Click({
            Update-Status 'Signing in to Microsoft Graph...'
            try {
                $State.Session = Connect-IntuneLaps
                Update-Status "Signed in as: $($State.Session.Account)" -Level $State.Session.EffectiveLevel
                $BtnSearch.IsEnabled     = $true
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
                $State.Session = $null
                Update-Status 'Not connected - click Sign In to authenticate'
                $BtnSearch.IsEnabled     = $false
                $BtnDisconnect.IsEnabled = $false
                $GridDevices.ItemsSource = $null
                $LblSelectedDevice.Text  = '- select a device'
                $BtnGetCredentials.IsEnabled = $false
                $TxtUsername.Text     = ''
                $PwdPassword.Password = ''
                $TxtPassword.Text     = ''
                $State.PlainPassword  = $null
            }
            catch {
                Update-Status "Sign out failed: $_"
            }
        })

        # ─── EVENT: Search ────────────────────────────────────────────────────────
        $BtnSearch.Add_Click({ Invoke-DeviceSearch })

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
                $TxtUsername.Text     = ''
                $PwdPassword.Password = ''
                $TxtPassword.Text     = ''
                $State.PlainPassword  = $null
                $BtnCopyUsername.IsEnabled   = $false
                $BtnCopyPassword.IsEnabled   = $false
                $BtnTogglePassword.IsEnabled = $false
            }
        })

        # ─── EVENT: Load Credentials ──────────────────────────────────────────────
        $BtnGetCredentials.Add_Click({
            if ($null -eq $GridDevices.SelectedItem) { return }

            [string]$DeviceId = $GridDevices.SelectedItem.DeviceId
            Update-Status 'Retrieving LAPS credentials...'

            try {
                $CredResult = Get-IntuneLapsCredential -DeviceId $DeviceId

                if ($null -eq $CredResult) {
                    Update-Status 'No LAPS record found for this device. Ensure LAPS is configured and the device has checked in recently.'
                    return
                }

                [bool]$HasCreds = ($null -ne $CredResult.Credentials -and $CredResult.Credentials.Count -gt 0)

                if ($HasCreds) {
                    # Display the newest credential (index 0 — sorted desc by BackupDateTime)
                    # When multiple accounts exist, a count note is shown in the status bar.
                    $Latest = $CredResult.Credentials[0]
                    $TxtUsername.Text     = $Latest.AccountName
                    $State.PlainPassword  = $Latest.Password
                    $PwdPassword.Password = $Latest.Password
                    $TxtPassword.Text     = $Latest.Password
                    $BtnCopyUsername.IsEnabled   = (-not [string]::IsNullOrEmpty($Latest.AccountName))
                    $BtnCopyPassword.IsEnabled   = $true
                    $BtnTogglePassword.IsEnabled = $true

                    [string]$CountNote = if ($CredResult.Credentials.Count -gt 1) {
                        " ($($CredResult.Credentials.Count) accounts — showing newest)"
                    } else { '' }
                    Update-Status "Credentials loaded for: $($CredResult.DeviceName)$CountNote" -Level $CredResult.EffectiveLevel
                }
                else {
                    $TxtUsername.Text     = ''
                    $PwdPassword.Password = ''
                    $TxtPassword.Text     = ''
                    $State.PlainPassword  = $null
                    $BtnCopyUsername.IsEnabled   = $false
                    $BtnCopyPassword.IsEnabled   = $false
                    $BtnTogglePassword.IsEnabled = $false

                    if ($CredResult.EffectiveLevel -eq [LapsPermissionLevel]::Full) {
                        [string]$AuNote = if ($State.Session -and $State.Session.HasAuScopedRoles()) {
                            ' Your role is AU-scoped — this device may be outside your Administrative Unit.'
                        } else { '' }
                        Update-Status "No credentials found for this device.$AuNote" -Level $CredResult.EffectiveLevel
                    }
                    else {
                        Update-Status 'Metadata loaded — no password access with current permissions.' -Level $CredResult.EffectiveLevel
                    }
                }
            }
            catch {
                Update-Status "Failed to load credentials: $_"
            }
        })

        # ─── EVENT: Toggle password visibility ────────────────────────────────────
        $BtnTogglePassword.Add_Click({
            $State.PasswordVisible = -not $State.PasswordVisible
            if ($State.PasswordVisible) {
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
            if (-not [string]::IsNullOrEmpty($State.PlainPassword)) {
                [System.Windows.Clipboard]::SetText($State.PlainPassword)
                Update-Status 'Password copied to clipboard - will be cleared in 30 seconds.'
                Start-ClipboardClearTimer -Seconds 30
            }
        })

        # ─── Check existing Graph session on open ─────────────────────────────────
        # WPF STA threads have their own module scope — $script:CurrentSession from the
        # calling thread is not inherited. Build-LapsSession reconstructs the session
        # from the existing Graph token (no browser) if already authenticated.
        $Window.Add_Loaded({
            try {
                $Ctx = Get-MgContext -ErrorAction SilentlyContinue
                if ($Ctx) {
                    $State.Session = Build-LapsSession
                    Update-Status "Already signed in as: $($State.Session.Account)" -Level $State.Session.EffectiveLevel
                    $BtnSearch.IsEnabled     = $true
                    $BtnDisconnect.IsEnabled = $true
                    Invoke-DeviceSearch
                }
                else {
                    Update-Status 'Not connected — click Sign In to authenticate.'
                    $BtnSearch.IsEnabled     = $false
                    $BtnDisconnect.IsEnabled = $false
                }
            }
            catch {
                Update-Status 'Not connected — click Sign In to authenticate.'
                $BtnSearch.IsEnabled     = $false
                $BtnDisconnect.IsEnabled = $false
            }
        })

        # ─── Clear clipboard and disconnect on window close ──────────────────────
        $Window.Add_Closing({
            if ($State.ClipTimer) { $State.ClipTimer.Stop() }
            [System.Windows.Clipboard]::Clear()
            Disconnect-IntuneLaps -ErrorAction SilentlyContinue
        })

        # ─── Show the window ──────────────────────────────────────────────────────
        $null = $Window.ShowDialog()
    }
}
