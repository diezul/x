# **Pawnshop Lockdown Script** - Displays a fullscreen image and locks the PC, with Telegram remote control.
# --- Configuration: update these variables for your environment ---
$ImageUrl  = "https://example.com/lockscreen.jpg"    # URL of the image to display (LOCK screen image)
$BotToken  = "123456:ABC-DEF_your_bot_token_here"    # Telegram Bot API token
$ChatID    = "1234567890"                            # Telegram chat ID to send notifications to

# Identify this PC/user
$Username  = [Environment]::UserName
$Computer  = [Environment]::MachineName

# Lock state file path
$LockFile  = "C:\lock_status.txt"
# Startup registry run key name and path
$RunKey    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "PawnShopLock"

# --- State check: determine whether to lock or exit ---
if (Test-Path $LockFile) {
    try {
        $state = Get-Content -Path $LockFile -ErrorAction Stop
    } catch {
        $state = $null
    }
    if ($state -eq "unlocked") {
        # If state is unlocked, ensure no startup, then exit.
        Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
        return  # exit script, do not lock
    }
}
# If file doesn't exist or not "unlocked", proceed with lock.
# Mark state as locked in the file:
"locked" | Out-File -FilePath $LockFile -Force

# Add this script to startup (current user Run key)
try {
    # Determine the full path to this script
    $ScriptPath = $MyInvocation.MyCommand.Path
    if (-not $ScriptPath) { $ScriptPath = $PSCommandPath }  # Fallback for older PS versions
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
} catch {
    Write-Warning "Failed to add startup registry entry: $_"
}

# Disable Task Manager (to prevent Ctrl+Alt+Del > Task Manager).
# Create the Policies\System key if missing, then set DisableTaskMgr = 1.
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "DisableTaskMgr" -Value 1 -Type DWord -Force

# Prepare .NET assemblies for WinForms
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# Set up a global low-level keyboard hook to block unwanted key combinations&#8203;:contentReference[oaicite:9]{index=9}
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class Lockdown {
    // Hook constants
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN    = 0x0100;
    private const int WM_KEYUP      = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP   = 0x0105;
    // Hook variables
    private static IntPtr hookId = IntPtr.Zero;
    private static HookProc hookProc = HookCallback;
    // Modifier key state trackers
    private static bool altPressed = false;
    private static bool ctrlPressed = false;
    private static bool shiftPressed = false;
    // Delegate for hook callback
    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);
    // Import WinAPI functions for hooks
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    // Install the keyboard hook
    public static bool InstallHook() {
        if (hookId != IntPtr.Zero) return false;
        IntPtr moduleHandle = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, moduleHandle, 0);
        return hookId != IntPtr.Zero;
    }
    // Uninstall the hook
    public static bool UninstallHook() {
        if (hookId == IntPtr.Zero) return false;
        bool result = UnhookWindowsHookEx(hookId);
        hookId = IntPtr.Zero;
        return result;
    }
    // Hook callback function: decide which keys to block
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            int msg = (int)wParam;
            bool block = false;
            if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN) {
                // Track modifier key presses
                if (key == Keys.LMenu || key == Keys.RMenu) { altPressed = true; block = true; }      // Alt down (block immediately)
                if (key == Keys.LControlKey || key == Keys.RControlKey) { ctrlPressed = true; }
                if (key == Keys.LShiftKey || key == Keys.RShiftKey)     { shiftPressed = true; }
                // Block certain keys/combos
                switch (key) {
                    case Keys.Tab:      if (altPressed) block = true; break;       // Alt+Tab
                    case Keys.F4:       if (altPressed) block = true; break;       // Alt+F4
                    case Keys.Escape:   if (ctrlPressed) block = true; break;      // Ctrl+Esc or Ctrl+Shift+Esc
                    case Keys.LWin:
                    case Keys.RWin:     block = true; break;                      // Windows key
                    case Keys.Delete:   if (ctrlPressed && altPressed) block = true; break;  // Ctrl+Alt+Del (attempt to block Delete key in that combo)
                }
            }
            else if (msg == WM_KEYUP || msg == WM_SYSKEYUP) {
                // Track modifier key releases
                if (key == Keys.LMenu || key == Keys.RMenu)         { altPressed = false; }
                if (key == Keys.LControlKey || key == Keys.RControlKey) { ctrlPressed = false; }
                if (key == Keys.LShiftKey || key == Keys.RShiftKey)     { shiftPressed = false; }
            }
            if (block) {
                // Swallow the key press (do not pass to next hook/OS)
                return (IntPtr)1;
            }
        }
        // Call next hook in chain for keys we are not blocking
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@ -ErrorAction Stop

# Install the keyboard hook to start intercepting keystrokes
[void][Lockdown]::InstallHook()

# Create full-screen form(s) on each monitor and display the image
$forms = New-Object System.Collections.Generic.List[System.Windows.Forms.Form]
try {
    # Download the image from the URL
    $webClient = New-Object System.Net.WebClient
    $imageData = $webClient.DownloadData($ImageUrl)
    $webClient.Dispose()
    $ms = New-Object System.IO.MemoryStream($imageData)
    $image = [System.Drawing.Image]::FromStream($ms)
} catch {
    Write-Warning "Failed to download image from $ImageUrl: $_"
    # Use a blank image/solid color if download fails
    $image = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, 
                                              [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
    [System.Drawing.Graphics]::FromImage($image).Clear([System.Drawing.Color]::Black)
}

foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    # Create a new form for this screen
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Bounds = $screen.Bounds    # Set form size to cover the entire screen&#8203;:contentReference[oaicite:10]{index=10}
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.KeyPreview = $true  # (not strictly needed due to global hook, but enables form-level key events if any)

    # Prevent closing the form via Alt+F4 (or any attempt) by cancelling the close event unless allowed
    $form.Add_FormClosing({
        param([System.Object] $sender, [System.Windows.Forms.FormClosingEventArgs] $e)
        if (-not $script:AllowClose) {
            $e.Cancel = $true
        }
    })

    # Add a PictureBox to display the image
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'
    $pb.SizeMode = 'Zoom'  # Use 'Zoom' to preserve aspect ratio (image will letterbox if aspect differs)
    $pb.Image = $image
    $form.Controls.Add($pb)

    $forms.Add($form)
}

# Show all forms
foreach ($f in $forms) { $f.Show() }

# Send Telegram notification about the lock activation
# Gather network info (local & public IPs)
$localIPs = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_ -ne [System.Net.IPAddress]::Loopback }
$LocalIP  = if ($localIPs) { $localIPs[0].ToString() } else { "Unknown" }
try {
    $PublicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10)
} catch {
    $PublicIP = "Unknown"
}
# Compose the message text with all required info and commands
$msg  = "Pawnshop PC Locked:`n"
$msg += "User: $Username`nComputer: $Computer`nLocal IP: $LocalIP`nPublic IP: $PublicIP`n`n"
$msg += "Commands: /unlock$Username, /shutdown$Username, /lock$Username"

# Send the message via Telegram Bot API
$sendParams = @{
    Uri         = "https://api.telegram.org/bot$BotToken/sendMessage"
    Method      = "POST"
    ContentType = "application/json"
    Body        = @{ chat_id = $ChatID; text = $msg } | ConvertTo-Json
}
try {
    Invoke-RestMethod @sendParams | Out-Null
} catch {
    Write-Warning "Failed to send Telegram notification: $_"
}

# Initialize Telegram updates polling (ignore any past messages by setting the offset to the latest update_id + 1)
$script:offset = 0
try {
    $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BotToken/getUpdates?timeout=1"
    if ($updates -and $updates.ok -and $updates.result) {
        $lastUpdateId = ($updates.result | Select-Object -Last 1 -ExpandProperty update_id)
        $script:offset = $lastUpdateId + 1
    }
} catch {
    $script:offset = 0
}

# Track current lock status in script
$script:isLocked = $true
$script:AllowClose = $false

# Set up a timer to poll Telegram for commands every 3 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000  # 3 seconds
$timer.Add_Tick({
    # Poll Telegram getUpdates for new commands
    try {
        $resp = Invoke-RestMethod -Uri ("https://api.telegram.org/bot$BotToken/getUpdates?offset=$script:offset")
    } catch {
        # Ignore network errors in polling
        return
    }
    if ($resp -and $resp.ok -and $resp.result) {
        foreach ($update in $resp.result) {
            # Process each new update
            if (-not ($update.message)) { continue }  # skip non-message updates
            $chatIdIn = $update.message.chat.id
            $textIn   = $update.message.text
            if ($ChatID -and ($chatIdIn.ToString() -ne $ChatID.ToString())) {
                continue  # ignore messages not from the authorized chat
            }
            if (-not $textIn) { continue }
            $t = $textIn.ToLower().Trim()
            $u = $Username.ToLower()
            if ($t -eq "/unlock$u" -or $t -eq "/unlock $u") {
                # Unlock command received
                "unlocked" | Out-File -FilePath $LockFile -Force   # update state file
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue  # remove startup
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
                    -Name "DisableTaskMgr" -Value 0 -Force -ErrorAction SilentlyContinue  # re-enable Task Manager
                $script:isLocked = $false
                # Close all forms and exit the application loop
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            }
            elseif ($t -eq "/shutdown$u" -or $t -eq "/shutdown $u") {
                # Shutdown command received
                # (Remove startup entry so it doesn't run on next boot if shutdown is effectively unlocking the cycle)
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                try {
                    Stop-Computer -Force -Confirm:$false
                } catch {
                    Write-Warning "Shutdown command failed: $_"
                }
                finally {
                    # Ensure Task Manager re-enabled in case system remains on
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
                        -Name "DisableTaskMgr" -Value 0 -Force -ErrorAction SilentlyContinue
                    $script:AllowClose = $true
                    [System.Windows.Forms.Application]::Exit()
                }
            }
            elseif ($t -eq "/lock$u" -or $t -eq "/lock $u") {
                # Lock command received
                if (-not $script:isLocked) {
                    # If somehow unlocked but script still running (not typical in this implementation), re-lock
                    $script:isLocked = $true
                    "locked" | Out-File -FilePath $LockFile -Force
                    # Re-add startup
                    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
                    # (We would also show the forms again if they were hidden, but in this design script would normally not be running if unlocked)
                }
                else {
                    # Already locked – ensure startup is set (just in case) and ignore command
                    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
                }
                # We do not exit; remain locked
            }
        }
        # Update offset to one past the last processed update_id
        $lastId = ($resp.result | Select-Object -Last 1 -ExpandProperty update_id)
        $script:offset = $lastId + 1
    }
})

# Start the timer
$timer.Start()

# Start the Windows Forms message loop (runs until Application.Exit is called)
[System.Windows.Forms.Application]::Run()

# ===== Cleanup after exit =====
# Stop the timer and dispose forms
$timer.Stop()
foreach ($f in $forms) {
    if (!$f.IsDisposed) { $f.Close() }
    $f.Dispose()
}
# Remove keyboard hook
[Lockdown]::UninstallHook() | Out-Null
# Ensure Task Manager is enabled back (in case of any unexpected exit)
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
